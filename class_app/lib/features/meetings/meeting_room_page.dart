import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:intl/intl.dart';
import 'package:signalr_core/signalr_core.dart';

import '../../core/config/app_config.dart';
import '../../data/repositories/meeting_repository_impl.dart';
import '../../core/services/token_provider.dart';
import '../../data/models/meeting_join_result.dart';

class MeetingRoomPage extends ConsumerStatefulWidget {
  const MeetingRoomPage({super.key, required this.result});

  final MeetingJoinResult result;

  @override
  ConsumerState<MeetingRoomPage> createState() => _MeetingRoomPageState();
}

class _MeetingRoomPageState extends ConsumerState<MeetingRoomPage> {
  final Map<String, RTCPeerConnection> _peers = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  RTCVideoRenderer? _screenRenderer;
  final List<_ChatMessage> _messages = [];
  final ValueNotifier<int> _chatVersion = ValueNotifier<int>(0);
  final List<_Participant> _participants = [];
  HubConnection? _hub;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  MediaStream? _screenStream;
  final List<RTCRtpSender> _screenSenders = [];
  bool _micOn = true;
  bool _camOn = true;
  bool _sharing = false;
  bool _connecting = true;
  late final bool _isHost;
  String? _pinnedId;

  String get _roomCode => widget.result.meeting.roomCode;

  @override
  void initState() {
    super.initState();
    final role = widget.result.role.toLowerCase();
    _isHost = role.contains('teacher') || role.contains('owner') || role.contains('host');
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _startLocalMedia();
    await _connectHub();
    setState(() => _connecting = false);
  }

  Future<void> _startLocalMedia() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
      },
    });
    _localStream = stream;
    _localRenderer.srcObject = stream;
  }

  Future<void> _connectHub() async {
    final token = ref.read(accessTokenProvider);
    final hub = HubConnectionBuilder()
        .withUrl(
          '${AppConfig.apiOrigin}/hubs/meeting',
          HttpConnectionOptions(
            accessTokenFactory: () async => token ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    hub.on('ParticipantsSnapshot', _onParticipantsSnapshot);
    hub.on('ParticipantJoined', _onParticipantJoined);
    hub.on('ParticipantLeft', _onParticipantLeft);
    hub.on('ReceiveOffer', _onReceiveOffer);
    hub.on('ReceiveAnswer', _onReceiveAnswer);
    hub.on('ReceiveIceCandidate', _onReceiveIce);
    hub.on('ReceiveChatMessage', _onChat);
    hub.on('MeetingEnded', (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuộc họp đã kết thúc')),
      );
      Navigator.of(context).pop();
    });

    await hub.start();
    _hub = hub;
    await hub.invoke('JoinRoom', args: [_roomCode]);
  }

  @override
  void dispose() {
    _hub?.stop();
    for (final pc in _peers.values) {
      pc.close();
    }
    for (final r in _remoteRenderers.values) {
      r.dispose();
    }
    _screenRenderer?.dispose();
    _localStream?.dispose();
    _screenStream?.dispose();
    _localRenderer.dispose();
    _chatVersion.dispose();
    super.dispose();
  }

  Future<RTCPeerConnection> _createPeer(String remoteId, {required bool isCaller}) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    final pc = await createPeerConnection(config);
    _peers[remoteId] = pc;

    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        _hub?.invoke('SendIceCandidate', args: [remoteId, candidate.toMap()]);
      }
    };

    pc.onTrack = (event) async {
      if (event.track.kind == 'video' || event.track.kind == 'audio') {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = event.streams.first;
        setState(() {
          _remoteRenderers[remoteId]?.dispose();
          _remoteRenderers[remoteId] = renderer;
        });
      }
    };

    if (isCaller) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await _hub?.invoke('SendOffer', args: [remoteId, offer.toMap()]);
    }

    return pc;
  }

  void _onParticipantsSnapshot(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final list = args.first as List<dynamic>;
    final myId = _hub?.connectionId;
    _participants.clear();
    for (final p in list) {
      final obj = p as Map;
      final connId = obj['connectionId']?.toString();
      final name = obj['userName']?.toString() ??
          obj['displayName']?.toString() ??
          'Người dùng';
      final userId = obj['userId']?.toString();
      if (connId != null) {
        _participants.add(
          _Participant(
            connectionId: connId,
            displayName: name,
            userId: userId,
          ),
        );
      }
      if (connId == null || connId == myId) continue;
      if (_peers.containsKey(connId)) continue;
      _createPeer(connId, isCaller: true);
    }
    setState(() {});
  }

  void _onParticipantJoined(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final from = (args.first as Map)['connectionId']?.toString();
    final name = (args.first as Map)['userName']?.toString() ??
        (args.first as Map)['displayName']?.toString() ??
        'Người dùng';
    final userId = (args.first as Map)['userId']?.toString();
    if (from == null) return;
    _participants.removeWhere((p) => p.connectionId == from);
    _participants.add(
      _Participant(connectionId: from, displayName: name, userId: userId),
    );
    _createPeer(from, isCaller: true);
    setState(() {});
  }

  void _onParticipantLeft(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final connId = (args.first as Map)['connectionId']?.toString();
    if (connId == null) return;
    _peers.remove(connId)?.close();
    _remoteRenderers.remove(connId)?.dispose();
    _participants.removeWhere((p) => p.connectionId == connId);
    setState(() {});
  }

  Future<void> _onReceiveOffer(List<Object?>? args) async {
    if (args == null || args.isEmpty) return;
    final payload = args.first as Map;
    final from = payload['from']?.toString();
    if (from == null) return;
    final offerMap = Map<String, dynamic>.from(payload['payload'] as Map);
    final pc = await _createPeer(from, isCaller: false);
    await pc.setRemoteDescription(RTCSessionDescription(
      offerMap['sdp'],
      offerMap['type'],
    ));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    await _hub?.invoke('SendAnswer', args: [from, answer.toMap()]);
  }

  Future<void> _onReceiveAnswer(List<Object?>? args) async {
    if (args == null || args.isEmpty) return;
    final payload = args.first as Map;
    final from = payload['from']?.toString();
    if (from == null) return;
    final answerMap = Map<String, dynamic>.from(payload['payload'] as Map);
    final pc = _peers[from];
    if (pc == null) return;
    await pc.setRemoteDescription(
      RTCSessionDescription(answerMap['sdp'], answerMap['type']),
    );
  }

  Future<void> _onReceiveIce(List<Object?>? args) async {
    if (args == null || args.isEmpty) return;
    final payload = args.first as Map;
    final from = payload['from']?.toString();
    if (from == null) return;
    final candidateMap = Map<String, dynamic>.from(payload['candidate'] as Map);
    final pc = _peers[from];
    if (pc == null) return;
    await pc.addCandidate(RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    ));
  }

  void _onChat(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final payload = args.first as Map;
    _addChatMessage(
      _ChatMessage(
        userName: payload['userName']?.toString() ?? 'Người dùng',
        message: payload['message']?.toString() ?? '',
        sentAt: DateTime.tryParse(payload['sentAt']?.toString() ?? '') ??
            DateTime.now(),
      ),
    );
  }

  void _togglePin(String id) {
    setState(() {
      if (_pinnedId == id) {
        _pinnedId = null;
      } else {
        _pinnedId = id;
      }
    });
  }

  Future<void> _toggleMic() async {
    _micOn = !_micOn;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = _micOn);
    setState(() {});
  }

  Future<void> _toggleCam() async {
    _camOn = !_camOn;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = _camOn);
    setState(() {});
  }

  Future<void> _toggleShare() async {
    if (_sharing) {
      for (final sender in _screenSenders) {
        await sender.replaceTrack(null);
      }
      _screenSenders.clear();
      await _screenStream?.dispose();
      await _screenRenderer?.dispose();
      _screenStream = null;
      _screenRenderer = null;
      setState(() {
        _sharing = false;
      });
      return;
    }

    try {
      final stream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false,
      });
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = stream;
      _screenStream = stream;
      _screenRenderer = renderer;

      for (final track in stream.getVideoTracks()) {
        for (final pc in _peers.values) {
          final sender = await pc.addTrack(track, stream);
          _screenSenders.add(sender);
        }
      }

      setState(() => _sharing = true);
    } catch (error) {
      setState(() => _sharing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chia sẻ màn hình: $error')),
      );
    }
  }

  Future<void> _sendChat(String text) async {
    if (text.trim().isEmpty) return;
    await _hub?.invoke('SendChatMessage', args: [text.trim()]);
  }

  void _addChatMessage(_ChatMessage msg) {
    if (!mounted) return;
    setState(() {
      _messages.add(msg);
      _chatVersion.value++;
    });
  }

  Future<void> _leave() async {
    try {
      await _hub?.invoke('LeaveRoom');
      final repo = ref.read(meetingRepositoryProvider);
      final meetingId = widget.result.meeting.id;
      if (_isHost) {
        await repo.endMeeting(meetingId);
      } else {
        await repo.leave(meetingId);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể rời cuộc họp: $error')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteTiles = _remoteRenderers.entries.toList();
    final participantCount = _participants.length;
    final tiles = <_Tile>[
      _Tile(
        id: 'local',
        renderer: _localRenderer,
        name: 'Bạn',
        avatarUrl: _avatarFor(_hub?.connectionId ?? ''),
        muted: !_micOn,
        cameraOff: !_camOn,
      ),
      ...remoteTiles.map(
        (entry) => _Tile(
          id: entry.key,
          renderer: entry.value,
          name: _displayNameFor(entry.key),
          avatarUrl: _avatarFor(entry.key),
          muted: false,
          cameraOff: false,
        ),
      ),
      if (_screenRenderer != null)
        _Tile(
          id: 'screen',
          renderer: _screenRenderer!,
          name: 'Chia sẻ màn hình',
          avatarUrl: null,
          muted: false,
          cameraOff: false,
        ),
    ];

    final hasPin = _pinnedId != null && tiles.length > 1;
    _Tile? pinned;
    List<_Tile> others = tiles;
    if (hasPin) {
      pinned = tiles.firstWhere(
        (t) => t.id == _pinnedId,
        orElse: () => tiles.first,
      );
      others = tiles.where((t) => t.id != pinned?.id).toList();
    }
    final crossAxis = others.length <= 1 ? 1 : 2;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: _connecting
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.result.meeting.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.people_alt_rounded,
                                      size: 14, color: Color(0xFF9CA3AF)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$participantCount người · Mã $_roomCode',
                                    style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Người tham gia',
                          icon: Stack(
                            children: [
                              const Icon(Icons.people_alt_outlined, color: Colors.white),
                              if (participantCount > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      participantCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onPressed: _showParticipants,
                        ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Row(
                      children: [
                        _InfoChip(
                          icon: Icons.verified_user,
                          label: _isHost ? 'Chủ phòng' : 'Người tham gia',
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.people_alt_outlined,
                          label: '$participantCount trong phòng',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: hasPin && pinned != null
                          ? Column(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _VideoTile(
                                    renderer: pinned.renderer,
                                    label: pinned.name,
                                    displayName: pinned.name,
                                    avatarUrl: pinned.avatarUrl,
                                    muted: pinned.muted,
                                    cameraOff: pinned.cameraOff,
                                    pinned: true,
                                    onTap: () => _togglePin(pinned!.id),
                                    onPin: () => _togglePin(pinned!.id),
                                  ),
                                ),
                                if (others.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 220,
                                    child: GridView.count(
                                      crossAxisCount: crossAxis,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      children: others
                                          .map(
                                            (t) => _VideoTile(
                                              renderer: t.renderer,
                                              label: t.name,
                                              displayName: t.name,
                                              avatarUrl: t.avatarUrl,
                                              muted: t.muted,
                                              cameraOff: t.cameraOff,
                                              onTap: () => _togglePin(t.id),
                                              onPin: () => _togglePin(t.id),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : GridView.count(
                              crossAxisCount: tiles.length <= 1 ? 1 : 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              children: tiles
                                  .map(
                                    (t) => _VideoTile(
                                      renderer: t.renderer,
                                      label: t.name,
                                      displayName: t.name,
                                      avatarUrl: t.avatarUrl,
                                      muted: t.muted,
                                      cameraOff: t.cameraOff,
                                      onTap: () => _togglePin(t.id),
                                      onPin: () => _togglePin(t.id),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ),
                  _ControlBar(
                    micOn: _micOn,
                    camOn: _camOn,
                  participantCount: participantCount,
                  onToggleMic: _toggleMic,
                  onToggleCam: _toggleCam,
                  onShowParticipants: _showParticipants,
                  onShareScreen: _toggleShare,
                  onShowChat: _showChatSheet,
                  onLeave: _leave,
                  sharing: _sharing,
                ),
              ],
            ),
      ),
    );
  }

  String _displayNameFor(String connectionId) {
    final p = _participants.firstWhere(
      (e) => e.connectionId == connectionId,
      orElse: () => _Participant(
        connectionId: connectionId,
        displayName: 'Người tham gia',
        userId: null,
      ),
    );
    return p.displayName;
  }

  String? _avatarFor(String connectionId) {
    final p = _participants.firstWhere(
      (e) => e.connectionId == connectionId,
      orElse: () => _Participant(
        connectionId: connectionId,
        displayName: '',
        userId: null,
      ),
    );
    if (p.userId == null) return null;
    final member = widget.result.classroom.members.firstWhere(
      (m) => m.userId == p.userId,
      orElse: () => const MeetingMember(userId: '', fullName: '', avatar: null),
    );
    return member.userId.isEmpty ? null : member.avatar;
  }

  void _showParticipants() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    const Text(
                      'Người tham gia',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const Spacer(),
                    Text(
                      '${_participants.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_participants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Chưa có ai trong phòng',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ),
                  )
                else
                  ..._participants.map(
                    (p) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE5EDFF),
                        child: Text(
                          p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      title: Text(
                        p.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        p.connectionId == _hub?.connectionId ? 'Bạn' : 'Đang tham gia',
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChatSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final controller = TextEditingController();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              top: 12,
            ),
            child: ValueListenableBuilder<int>(
              valueListenable: _chatVersion,
              builder: (_, __, ___) {
                final reversed = _messages.reversed.toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.chat_bubble_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Chat trong phòng',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 260,
                      child: ListView.builder(
                        reverse: true,
                        itemCount: reversed.length,
                        itemBuilder: (context, index) {
                          final msg = reversed[index];
                          final time = DateFormat('HH:mm').format(msg.sentAt.toLocal());
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF1D4ED8),
                                  child: Text(
                                    msg.userName.isNotEmpty
                                        ? msg.userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              msg.userName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            time,
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        msg.message,
                                        style: const TextStyle(
                                          color: Color(0xFFCBD5E1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              hintText: 'Nhắn tin trong phòng...',
                              hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF1F2937)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final text = controller.text;
                            controller.clear();
                            await _sendChat(text);
                          },
                          child: const Icon(Icons.send, size: 18),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({
    required this.renderer,
    required this.label,
    this.displayName,
    this.avatarUrl,
    this.muted = false,
    this.cameraOff = false,
    this.pinned = false,
    this.onTap,
    this.onPin,
  });

  final RTCVideoRenderer renderer;
  final String label;
  final String? displayName;
  final String? avatarUrl;
  final bool muted;
  final bool cameraOff;
  final bool pinned;
  final VoidCallback? onTap;
  final VoidCallback? onPin;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: pinned
              ? Border.all(color: const Color(0xFF2563EB), width: 2)
              : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: cameraOff
                  ? _AvatarFallback(name: displayName ?? label, avatarUrl: avatarUrl)
                  : RTCVideoView(renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          label,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        if (muted) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.mic_off, color: Colors.redAccent, size: 16),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                onPressed: onPin,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: pinned
                        ? Border.all(color: const Color(0xFF2563EB), width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 16,
                    color: pinned ? const Color(0xFF2563EB) : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        image: avatarUrl != null && avatarUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? const SizedBox.shrink()
          : Center(
              child: CircleAvatar(
                radius: 46,
                backgroundColor: const Color(0xFF111827),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.micOn,
    required this.camOn,
    required this.participantCount,
    required this.onToggleMic,
    required this.onToggleCam,
    required this.onShowParticipants,
    required this.onShareScreen,
    required this.onShowChat,
    required this.onLeave,
    required this.sharing,
  });

  final bool micOn;
  final bool camOn;
  final int participantCount;
  final Future<void> Function() onToggleMic;
  final Future<void> Function() onToggleCam;
  final VoidCallback onShowParticipants;
  final Future<void> Function() onShareScreen;
  final VoidCallback onShowChat;
  final Future<void> Function() onLeave;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CircleButton(
            color: micOn ? Colors.blue : Colors.red,
            icon: micOn ? Icons.mic : Icons.mic_off,
            onTap: onToggleMic,
          ),
          _CircleButton(
            color: camOn ? Colors.blue : Colors.red,
            icon: camOn ? Icons.videocam : Icons.videocam_off,
            onTap: onToggleCam,
          ),
          _CircleButton(
            color: Colors.grey.shade800,
            icon: Icons.people_alt,
            badge: participantCount > 0 ? participantCount.toString() : null,
            onTap: () async {
              onShowParticipants();
            },
          ),
          _CircleButton(
            color: sharing ? const Color(0xFF10B981) : Colors.grey.shade800,
            icon: sharing ? Icons.stop_screen_share : Icons.screen_share_outlined,
            onTap: onShareScreen,
          ),
          _CircleButton(
            color: Colors.grey.shade800,
            icon: Icons.chat_bubble_outline,
            onTap: () async {
              onShowChat();
            },
          ),
          _CircleButton(
            color: const Color(0xFFE11D48), // red hang-up
            icon: Icons.call_end,
            onTap: onLeave,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.color,
    required this.icon,
    required this.onTap,
    this.badge,
    this.active = false,
  });

  final Color color;
  final IconData icon;
  final Future<void> Function() onTap;
  final String? badge;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
      decoration: BoxDecoration(
        color: active ? color : color,
        shape: BoxShape.circle,
      ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white),
            if (badge != null)
              Positioned(
                right: 6,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.userName, required this.message, required this.sentAt});

  final String userName;
  final String message;
  final DateTime sentAt;
}

class _Participant {
  _Participant({
    required this.connectionId,
    required this.displayName,
    required this.userId,
  });

  final String connectionId;
  final String displayName;
  final String? userId;
}

class _Tile {
  _Tile({
    required this.id,
    required this.renderer,
    required this.name,
    this.avatarUrl,
    this.muted = false,
    this.cameraOff = false,
  });

  final String id;
  final RTCVideoRenderer renderer;
  final String name;
  final String? avatarUrl;
  final bool muted;
  final bool cameraOff;
}

class _ChatPanel extends StatefulWidget {
  const _ChatPanel({required this.messages, required this.onSend});

  final List<_ChatMessage> messages;
  final Future<void> Function(String text) onSend;

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFF),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: ListView.builder(
              reverse: true,
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final msg = widget.messages.reversed.toList()[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          msg.userName.isNotEmpty ? msg.userName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Text(
                              msg.message,
                              style: const TextStyle(color: Color(0xFF4B5563)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Nhắn tin trong phòng...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final text = _controller.text;
                  _controller.clear();
                  await widget.onSend(text);
                },
                child: const Icon(Icons.send, size: 18),
              )
            ],
          ),
        ],
      ),
    );
  }
}

using class_api.Application;
using class_api.Infrastructure.Data;
using class_api.Filters;
using class_api.Services;
using class_api.Hubs;
using class_api.Application.Interfaces;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using class_api.Json;
using class_api.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.UseUrls("http://0.0.0.0:5081");

builder.Services.AddApplicationServices();
builder.Services.AddInfrastructureServices(builder.Configuration);

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, CurrentUser>();
builder.Services.AddHttpClient();
builder.Services.AddControllers().AddJsonOptions(o =>
{
    o.JsonSerializerOptions.Converters.Add(new DateTimeUtcConverter());
    o.JsonSerializerOptions.Converters.Add(new NullableDateTimeUtcConverter());
});
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
var jwtKeyConfig = builder.Configuration["Jwt:Key"] ?? string.Empty;

builder.Services.AddSignalR();
builder.Services.AddHttpClient();
builder.Services.AddSingleton<IActivityStream, ActivityStream>();
builder.Services.AddScoped<INotificationService, NotificationService>();

builder.Services.AddAuthentication("Bearer")
   .AddJwtBearer(opt =>
   {
       var key = Encoding.UTF8.GetBytes(jwtKeyConfig);
       opt.TokenValidationParameters = new TokenValidationParameters
       {
           ValidateIssuer = true,
           ValidateAudience = true,
           ValidateLifetime = true,
           ValidateIssuerSigningKey = true,
           ValidIssuer = builder.Configuration["Jwt:Issuer"],
           ValidAudience = builder.Configuration["Jwt:Audience"],
           IssuerSigningKey = new SymmetricSecurityKey(key)
       };

       opt.Events = new JwtBearerEvents
       {
           OnAuthenticationFailed = ctx =>
           {
               Console.WriteLine($"❌ JWT invalid: {ctx.Exception.Message}");
               return Task.CompletedTask;
           },
           OnTokenValidated = ctx =>
           {
               Console.WriteLine("✅ JWT validated successfully");
               return Task.CompletedTask;
           },
           OnMessageReceived = ctx =>
           {
               var accessToken = ctx.Request.Query["access_token"];
               var path = ctx.HttpContext.Request.Path;
               if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
               {
                   ctx.Token = accessToken;
               }
               return Task.CompletedTask;
           }
       };
   });


builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy =>
        policy.RequireClaim("systemRole", "Admin"));
});

builder.Services.AddControllers(options =>
{
    options.Filters.Add<ApiExceptionFilter>();
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowApp",
        b => b
            .SetIsOriginAllowed(origin =>
            {
                if (string.IsNullOrWhiteSpace(origin)) return false;
                if (Uri.TryCreate(origin, UriKind.Absolute, out var uri))
                {
                    return uri.Host == "localhost" || uri.Host == "127.0.0.1" || uri.Host == "10.0.2.2";
                }
                return false;
            })
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials());
});
builder.Configuration
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true);
    
    if (builder.Environment.IsEnvironment("Docker"))
    {
        builder.Configuration.AddJsonFile("appsettings.Docker.json", optional: true, reloadOnChange: true);
    }

builder.Configuration.AddEnvironmentVariables();

var app = builder.Build();
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    DbSeeder.SeedAdmin(db);
}
app.UseSwagger();
app.UseSwaggerUI();
app.UseStaticFiles();
app.UseCors("AllowApp");
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<ClassroomHub>("/hubs/classroom");
app.MapHub<MeetingHub>("/hubs/meeting");
app.MapHub<NotificationHub>("/hubs/notifications");
app.MapHub<ActivityHub>("/hubs/activity");

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    db.Database.Migrate();
}

app.Run();

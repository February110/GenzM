# build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# copy project files for restore
COPY class_solution/class.api/class.Api.csproj class_solution/class.api/
COPY class_solution/class.Application/class.Application.csproj class_solution/class.Application/
COPY class_solution/class.Domain/class.Domain.csproj class_solution/class.Domain/
COPY class_solution/class.Infrastructure/class.Infrastructure.csproj class_solution/class.Infrastructure/
RUN dotnet restore class_solution/class.api/class.Api.csproj

# copy source
COPY class_solution/ class_solution/
WORKDIR /src/class_solution/class.api
RUN dotnet publish -c Release -o /app/publish

# runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish .

EXPOSE 5081
ENTRYPOINT ["dotnet", "class.Api.dll"]

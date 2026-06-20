# MealTracker Combined

Monorepo combining the **MacrosSimple iOS app** and the **meal-tracker-web** microservices backend.

| Directory | Source repo | Description |
|-----------|-------------|-------------|
| [`ios/`](ios/) | [MealTracker](https://github.com/asimonleeaustralia-max/MealTracker) | Swift/SwiftUI iOS app (Xcode project) |
| [`services/`](services/) | [meal-tracker-web](https://github.com/asimonleeaustralia-max/meal-tracker-web) | FastAPI microservices (auth, meals, nutrition, vision, API gateway, web frontend) |
| [`libs/`](libs/) | meal-tracker-web | Shared Python libraries |
| [`infra/`](infra/) | meal-tracker-web | Azure Bicep infrastructure |
| [`scripts/`](scripts/) | meal-tracker-web | Deployment and smoke-test scripts |
| [`docs/`](docs/) | meal-tracker-web | iOS sync, auth, and deployment documentation |

## Quick start

### iOS app

Open `ios/MealTracker.xcodeproj` in Xcode and build for your target device or simulator.

### Backend (local dev)

```bash
docker compose up --build
```

See [`docs/azure-deployment.md`](docs/azure-deployment.md) for production deployment on Azure.

## Architecture

The iOS app stores meals locally in Core Data and syncs with the backend via the meal-service API. The web frontend and API gateway provide a browser-based interface. Vision recognition runs on RunPod via the vision-service.

```
iOS app (ios/)  ──┐
                  ├──► api-gateway ──► auth / meal / nutrition / vision services ──► PostgreSQL
Web UI            ──┘
```

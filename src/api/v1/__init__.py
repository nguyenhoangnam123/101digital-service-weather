from fastapi import APIRouter

from src.api.v1.routers.weather import routers as weather_router

routers = APIRouter(
    prefix="/api/v1",
)

routers.include_router(weather_router)

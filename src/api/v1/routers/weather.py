from fastapi import APIRouter
import requests
import logging
from src.api.schema.open_weather_rest import OpenWeatherRestRequest
from fastapi.responses import JSONResponse

routers = APIRouter(
    prefix="/weather",
    # route_class=ProtectedAPIRoute,
)

OPEN_WEATHER_REST = OpenWeatherRestRequest()

logger = logging.getLogger(__name__)


@routers.get("/get-today-weather")
async def get_today_weather():
    response = requests.get(f"{OPEN_WEATHER_REST.get_weather_url()}", headers={"Content-Type": "application/json"})
    logger.info(f"response is {response.json()}, status is {response.status_code}")
    return JSONResponse(status_code=response.status_code, content=response.json())

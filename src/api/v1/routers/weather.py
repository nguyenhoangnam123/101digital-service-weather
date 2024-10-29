import logging

import requests
from fastapi import APIRouter
from fastapi import Depends
from fastapi.responses import JSONResponse
from fastapi_cloudauth.cognito import Cognito
from pydantic import BaseModel

from src.api.schema.open_weather_rest import OpenWeatherRestRequest
from src.settings.config import get_settings

routers = APIRouter(
    prefix="/weather",
)

OPEN_WEATHER_REST = OpenWeatherRestRequest()

logger = logging.getLogger(__name__)

settings = get_settings()


auth = Cognito(
    region=settings.aws_default_region,
    userPoolId=settings.cognito_user_pool_id,
    client_id=settings.cognito_app_client_id,
    scope_key=settings.cognito_scope_key
)


class AccessUser(BaseModel):
    sub: str
    scope: str


@routers.get("/get-today-weather", dependencies=[Depends(auth.scope(["https://auth.dev.mightybee.dev/get:today-weather"]))])
async def get_today_weather():
    response = requests.get(f"{OPEN_WEATHER_REST.get_weather_url()}", headers={"Content-Type": "application/json"})
    logger.info(f"response is {response.json()}, status is {response.status_code}")
    return JSONResponse(status_code=response.status_code, content=response.json())

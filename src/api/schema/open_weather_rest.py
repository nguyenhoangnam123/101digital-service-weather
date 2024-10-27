from pydantic import BaseModel

from src.settings.config import settings


class OpenWeatherRestRequest:
    def __init__(self):
        self.url_prefix = f"{settings.open_weather_domain}/{settings.open_weather_api_version}"
        self.api_key = settings.open_weather_api_key.get_secret_value()

    def get_weather_url(self):
        lat, long = settings.coord_latitude, settings.coord_longitude
        return f"{self.url_prefix}/weather?lat={lat}&lon={long}&appid={self.api_key}"


class OpenWeatherRequestModel(BaseModel):
    pass

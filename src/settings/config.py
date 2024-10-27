from typing import Tuple
from typing import Type

from pydantic import Field
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic_settings import PydanticBaseSettingsSource


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env.local', env_file_encoding='utf-8')
    open_weather_api_key: SecretStr = Field("", env="OPEN_WEATHER_API_KEY")
    open_weather_domain: str = Field("", env="OPEN_WEATHER_DOMAIN")
    open_weather_api_version: str = Field("", env="OPEN_WEATHER_API_VERSION")
    coord_longitude: str = Field("", env="COORD_LONGITUDE")
    coord_latitude: str = Field("", env="COORD_LATITUDE")

    @classmethod
    def settings_customise_sources(
            cls,
            settings_cls: Type[BaseSettings],
            init_settings: PydanticBaseSettingsSource,
            env_settings: PydanticBaseSettingsSource,
            dotenv_settings: PydanticBaseSettingsSource,
            file_secret_settings: PydanticBaseSettingsSource,
    ) -> Tuple[PydanticBaseSettingsSource, ...]:
        return (
            init_settings,
            env_settings,
            dotenv_settings,
            file_secret_settings,
        )


settings = Settings()

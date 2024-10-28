from functools import lru_cache
from typing import Tuple
from typing import Type

from pydantic import Field
from pydantic import SecretStr
from pydantic_settings import BaseSettings
from pydantic_settings import PydanticBaseSettingsSource


class Settings(BaseSettings):
    open_weather_api_key: SecretStr = Field("", env="OPEN_WEATHER_API_KEY")
    open_weather_domain: str = Field("", env="OPEN_WEATHER_DOMAIN")
    open_weather_api_version: str = Field("", env="OPEN_WEATHER_API_VERSION")
    coord_longitude: str = Field("", env="COORD_LONGITUDE")
    coord_latitude: str = Field("", env="COORD_LATITUDE")
    aws_default_region: str = Field("", env="AWS_DEFAULT_REGION")
    cognito_user_pool_id: str = Field("", env="COGNITO_USER_POOL_ID")
    cognito_app_client_id: str = Field("", env="COGNITO_APP_CLIENT_ID")
    cognito_app_secret_id: str = Field("", env="COGNITO_APP_SECRET_ID")
    cognito_jwks_url: str = Field("", env="COGNITO_JWKS_URL")
    cognito_domain: str = Field("", env="COGNITO_DOMAIN")
    cognito_scope_key: str = Field("", env="COGNITO_SCOPE_KEY")

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


@lru_cache
def get_settings():
    return Settings()

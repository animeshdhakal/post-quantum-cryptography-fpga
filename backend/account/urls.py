from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    RegisterView,
    EmailTokenObtainPairView,
    UserProfileView,
    ChangePasswordView,
    LogoutView,
    UserSearchView
)

urlpatterns = [
    path("login/", EmailTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("login/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("register/", RegisterView.as_view(), name="auth_register"),
    path('profile/', UserProfileView.as_view(), name='profile'), # Modified name
    path('users/search/', UserSearchView.as_view(), name='user-search'), # Added new path
    path('profile/change_password/', ChangePasswordView.as_view(), name='change_password'), # Modified path
    path("logout/", LogoutView.as_view(), name="logout"),
]

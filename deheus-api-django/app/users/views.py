import crypto
import datetime as dt
import secrets

from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView

from users.models import User
from users.serializers import LoginSerializer, UserSerializer
from tenant.middleware import tenant_context


class LoginView(generics.GenericAPIView):
    serializer_class = LoginSerializer

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(serializer.validated_data, status=status.HTTP_200_OK)


class RefreshTokenView(TokenRefreshView):
    pass


class LogoutView(generics.GenericAPIView):
    def post(self, request, *args, **kwargs):
        refresh_token = request.data.get('refresh')
        if refresh_token:
            try:
                token = RefreshToken(refresh_token)
                token.blacklist()
            except Exception:
                pass
        return Response({'message': 'Logged out successfully'})


class ForgotPasswordView(generics.GenericAPIView):
    def post(self, request, *args, **kwargs):
        email = request.data.get('email', '').strip()
        if not email:
            return Response({'error': 'Email is required'}, status=status.HTTP_400_BAD_REQUEST)

        reset_token = secrets.token_urlsafe(64)
        reset_expiry = timezone.now() + dt.timedelta(hours=1)

        user = User.objects.filter(email=email)
        if user.exists():
            user.update(
                password_reset_token=reset_token,
                password_reset_expires=reset_expiry,
            )

        # Return token for testing (in production, send via email)
        return Response({
            'message': 'If an account exists for this email, a reset link has been sent.',
            'resetToken': reset_token,
        })


class ResetPasswordView(generics.GenericAPIView):
    def post(self, request, *args, **kwargs):
        token = request.data.get('token')
        password = request.data.get('password')
        if not token or not password:
            return Response(
                {'error': 'Token and password are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(password) < 6:
            return Response(
                {'error': 'Password must be at least 6 characters'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            user = User.objects.get(
                password_reset_token=token,
                password_reset_expires__gt=timezone.now(),
            )
        except User.DoesNotExist:
            return Response(
                {'error': 'Invalid or expired token'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        user.password_hash = make_password(password)
        user.password_reset_token = None
        user.password_reset_expires = None
        user.save()

        return Response({'message': 'Password updated successfully'})


class MeView(generics.GenericAPIView):
    def get(self, request, *args, **kwargs):
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

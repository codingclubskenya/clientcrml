from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken
from users.models import User
from tenant.serializers import TenantSerializer


class UserSerializer(serializers.ModelSerializer):
    tenant = TenantSerializer(read_only=True)

    class Meta:
        model = User
        fields = [
            'id', 'email', 'full_name', 'phone', 'role',
            'is_synced', 'created_at', 'updated_at', 'tenant',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        from django.contrib.auth.hashers import check_password
        import bcrypt

        user = User.objects.filter(email=data['email'], tenant__is_active=True).first()
        if user is None:
            raise serializers.ValidationError('Invalid credentials')

        password_valid = False
        if user.password_hash:
            if user.password_hash.startswith('$2'):
                password_valid = check_password(data['password'], user.password_hash)
            else:
                try:
                    password_valid = bcrypt.checkpw(
                        data['password'].encode('utf-8'),
                        user.password_hash.encode('utf-8'),
                    )
                except Exception:
                    password_valid = False
        elif user.has_usable_password():
            password_valid = user.check_password(data['password'])

        if not password_valid:
            raise serializers.ValidationError('Invalid credentials')

        refresh = _UserToken.for_user(user)
        return {
            'user': UserSerializer(user).data,
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        }


class _UserToken(RefreshToken):
    @classmethod
    def for_user(cls, user):
        token = super().for_user(user)
        if user.tenant_id:
            token['tenant_id'] = str(user.tenant_id)
        token['role'] = user.role
        token['email'] = user.email
        token['full_name'] = user.full_name or ''
        return token


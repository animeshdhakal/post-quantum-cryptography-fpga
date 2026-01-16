from django.contrib.auth import get_user_model
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """Serializer for User model"""
    class Meta:
        model = User
        fields = ["id", "username", "email", "date_joined", "last_login"]
        read_only_fields = ["id", "date_joined", "last_login"]


class RegisterSerializer(serializers.ModelSerializer):
    """Serializer for user registration"""
    password = serializers.CharField(
        write_only=True,
        required=True,
        style={'input_type': 'password'},
        min_length=8,
        help_text="Password must be at least 8 characters long"
    )
    password_confirm = serializers.CharField(
        write_only=True,
        required=True,
        style={'input_type': 'password'},
        help_text="Enter the same password as above, for verification"
    )
    email = serializers.EmailField(required=True)
    username = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=150,
        help_text="Optional. If not provided, will be generated from email"
    )

    class Meta:
        model = User
        fields = ["email", "username", "password", "password_confirm"]

    def validate_email(self, value):
        """Check if email is already registered"""
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value.lower()

    def validate(self, attrs):
        """Validate password confirmation"""
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({"password": "Password fields didn't match."})
        return attrs

    def create(self, validated_data):
        """Create a new user"""
        validated_data.pop('password_confirm')
        email = validated_data.pop('email')
        username = validated_data.get('username')
        
        # Generate username from email if not provided
        if not username:
            username = email.split('@')[0]
            # Ensure username is unique
            base_username = username
            counter = 1
            while User.objects.filter(username=username).exists():
                username = f"{base_username}{counter}"
                counter += 1
        
        user = User.objects.create_user(
            email=email,
            username=username,
            password=validated_data['password']
        )
        return user


class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Custom token serializer that uses email instead of username"""
    username_field = 'email'
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Replace 'username' field with 'email' field
        # This ensures the serializer accepts 'email' in request data
        if 'username' in self.fields:
            self.fields['email'] = self.fields.pop('username')
            self.fields['email'].required = True
            self.fields['email'].label = 'Email'

    def validate(self, attrs):
        """Validate credentials and return tokens"""
        # Map email to username for the parent serializer's authentication
        # The parent serializer expects 'username' in attrs for user lookup
        email = attrs.get('email', attrs.get('username'))
        if email:
            attrs['username'] = email
        data = super().validate(attrs)
        
        # Add user data to response
        data['user'] = UserSerializer(self.user).data
        return data


class ChangePasswordSerializer(serializers.Serializer):
    """Serializer for password change"""
    old_password = serializers.CharField(required=True, write_only=True)
    new_password = serializers.CharField(required=True, write_only=True, min_length=8)
    new_password_confirm = serializers.CharField(required=True, write_only=True)

    def validate(self, attrs):
        """Validate password confirmation"""
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError({"new_password": "New password fields didn't match."})
        return attrs
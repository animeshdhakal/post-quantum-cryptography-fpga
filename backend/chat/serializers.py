from rest_framework import serializers
from .models import Room, Message
from django.contrib.auth import get_user_model

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    is_online = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ["id", "username", "email", "is_online"]

    def get_is_online(self, obj):
        try:
            return obj.presence.is_online
        except:
            return False


from .kyber_service import kyber_service


class MessageSerializer(serializers.ModelSerializer):
    sender = UserSerializer(read_only=True)

    class Meta:
        model = Message
        fields = ["id", "room", "sender", "content", "timestamp", "is_read", "read_at"]
        read_only_fields = ["room", "sender", "timestamp", "read_at"]

    def create(self, validated_data):
        # Encrypt content before saving
        content = validated_data.get("content", "")
        if content:
            validated_data["content"] = kyber_service.encrypt(content)
        return super().create(validated_data)

    def to_representation(self, instance):
        # Decrypt content when sending to client
        ret = super().to_representation(instance)
        ret["content"] = kyber_service.decrypt(ret["content"])
        return ret


class RoomSerializer(serializers.ModelSerializer):
    participants = UserSerializer(many=True, read_only=True)
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = Room
        fields = [
            "id",
            "name",
            "participants",
            "created_at",
            "last_message",
            "unread_count",
        ]

    def get_last_message(self, obj):
        last_msg = obj.messages.order_by("-timestamp").first()
        if last_msg:
            return MessageSerializer(last_msg).data
        return None

    def get_unread_count(self, obj):
        user = self.context.get("request").user if self.context.get("request") else None
        if user and user.is_authenticated:
            return obj.messages.filter(is_read=False).exclude(sender=user).count()
        return 0

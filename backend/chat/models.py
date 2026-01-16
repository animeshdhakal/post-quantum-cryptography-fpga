from django.db import models
from django.contrib.auth import get_user_model

User = get_user_model()

class Room(models.Model):
    name = models.CharField(max_length=255, unique=True)
    participants = models.ManyToManyField(User, related_name="chats")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

class Message(models.Model):
    room = models.ForeignKey(Room, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name="sent_messages")
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.sender.email}: {self.content[:20]}"

class UserPresence(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="presence")
    last_seen = models.DateTimeField(auto_now=True)
    is_online = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.user.username}: {'Online' if self.is_online else 'Offline'}"

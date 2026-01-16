import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
from .models import Room, Message

User = get_user_model()


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.room_id = self.scope["url_route"]["kwargs"]["room_name"]
        self.room_group_name = f"chat_{self.room_id}"

        # Check if user is authenticated
        self.user = self.scope.get("user")
        if not self.user or self.user.is_anonymous:
            await self.close()
            return

        # Check if user is participant of the room
        if not await self.is_participant(self.room_id, self.user):
            await self.close()
            return

        # Join room group
        await self.channel_layer.group_add(self.room_group_name, self.channel_name)

        await self.update_user_presence(True)

        await self.accept()

        # Notify others in all shared rooms about online status
        contacts = await self.get_user_contacts(self.user.id)
        for contact_id in contacts:
            await self.channel_layer.group_send(
                f"notify_{contact_id}",
                {
                    "type": "notification",
                    "payload": {
                        "type": "user_presence",
                        "user_id": self.user.id,
                        "is_online": True,
                    },
                },
            )

        # Notify others in CURRENT room about online status (via room group too)
        await self.channel_layer.group_send(
            self.room_group_name,
            {"type": "user_presence", "user_id": self.user.id, "is_online": True},
        )

    async def disconnect(self, close_code):
        # Leave room group
        if hasattr(self, "room_group_name"):
            await self.update_user_presence(False)

            # Notify others in all shared rooms about offline status
            contacts = await self.get_user_contacts(self.user.id)
            for contact_id in contacts:
                await self.channel_layer.group_send(
                    f"notify_{contact_id}",
                    {
                        "type": "notification",
                        "payload": {
                            "type": "user_presence",
                            "user_id": self.user.id,
                            "is_online": False,
                        },
                    },
                )

            # Notify others in CURRENT room group
            await self.channel_layer.group_send(
                self.room_group_name,
                {"type": "user_presence", "user_id": self.user.id, "is_online": False},
            )

            await self.channel_layer.group_discard(
                self.room_group_name, self.channel_name
            )

    # Receive message from WebSocket
    async def receive(self, text_data):
        from .kyber_service import kyber_service

        try:
            data = json.loads(text_data)
            msg_type = data.get("type")

            if msg_type == "chat_message" or "content" in data:
                content = data.get("content") or data.get("message")
                if not content:
                    return

                # Encrypt content before saving
                encrypted_content = kyber_service.encrypt(content)

                # Save message to database
                message_obj = await self.save_message(
                    self.room_id, self.user, encrypted_content
                )

                # Send message to room group (send Encrypted content)
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        "type": "chat_message",
                        "id": message_obj.id,
                        "content": message_obj.content,  # Encrypted
                        "sender": {
                            "id": self.user.id,
                            "username": self.user.username
                            or self.user.email.split("@")[0],
                            "email": self.user.email,
                        },
                        "timestamp": message_obj.timestamp.isoformat(),
                        "is_read": False,
                    },
                )

                # Send notification to other participants' global notify channel
                participants = await self.get_room_participants(self.room_id)
                for p_id in participants:
                    if p_id != self.user.id:
                        await self.channel_layer.group_send(
                            f"notify_{p_id}",
                            {
                                "type": "notification",
                                "payload": {
                                    "type": "new_message",
                                    "room_id": self.room_id,
                                    "message": {
                                        "id": message_obj.id,
                                        "content": content,  # Plaintext for notification
                                        "sender": self.user.username,
                                        "timestamp": message_obj.timestamp.isoformat(),
                                    },
                                },
                            },
                        )

            elif msg_type == "typing":
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        "type": "typing",
                        "user_id": self.user.id,
                        "username": self.user.username,
                        "is_typing": data.get("is_typing", False),
                    },
                )

            elif msg_type == "read_receipt":
                # Mark messages as read
                await self.mark_messages_as_read(self.room_id, self.user)

                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        "type": "read_receipt",
                        "room_id": self.room_id,
                        "user_id": self.user.id,
                    },
                )

                # Notify sender that their messages were read via global notify channel
                participants = await self.get_room_participants(self.room_id)
                for p_id in participants:
                    if p_id != self.user.id:
                        await self.channel_layer.group_send(
                            f"notify_{p_id}",
                            {
                                "type": "notification",
                                "payload": {
                                    "type": "read_receipt",
                                    "room_id": self.room_id,
                                    "user_id": self.user.id,
                                },
                            },
                        )

        except Exception as e:
            print(f"WS Receive Error: {e}")

    # Receive message from room group
    async def chat_message(self, event):
        from .kyber_service import kyber_service

        # Decrypt content before sending to WebSocket
        decrypted_content = kyber_service.decrypt(event["content"])

        # Send message to WebSocket
        await self.send(
            text_data=json.dumps(
                {
                    "type": "message",
                    "id": event["id"],
                    "content": decrypted_content,
                    "sender": event["sender"],
                    "timestamp": event["timestamp"],
                    "is_read": event.get("is_read", False),
                }
            )
        )

    async def typing(self, event):
        # Don't send typing notification back to the sender
        if event["user_id"] != self.user.id:
            await self.send(
                text_data=json.dumps(
                    {
                        "type": "typing",
                        "user_id": event["user_id"],
                        "username": event["username"],
                        "is_typing": event["is_typing"],
                    }
                )
            )

    async def read_receipt(self, event):
        # Send read receipt to WebSocket
        await self.send(
            text_data=json.dumps(
                {
                    "type": "read_receipt",
                    "room_id": event["room_id"],
                    "user_id": event["user_id"],
                }
            )
        )

    async def user_presence(self, event):
        # Send presence update to WebSocket
        await self.send(
            text_data=json.dumps(
                {
                    "type": "user_presence",
                    "user_id": event["user_id"],
                    "is_online": event["is_online"],
                }
            )
        )

    @database_sync_to_async
    def is_participant(self, room_id, user):
        try:
            room = Room.objects.get(id=room_id)
            return room.participants.filter(id=user.id).exists()
        except Room.DoesNotExist:
            return False

    @database_sync_to_async
    def save_message(self, room_id, user, content):
        room = Room.objects.get(id=room_id)
        return Message.objects.create(room=room, sender=user, content=content)

    @database_sync_to_async
    def mark_messages_as_read(self, room_id, user):
        from django.utils import timezone

        return (
            Message.objects.filter(room_id=room_id, is_read=False)
            .exclude(sender=user)
            .update(is_read=True, read_at=timezone.now())
        )

    @database_sync_to_async
    def get_room_participants(self, room_id):
        try:
            room = Room.objects.get(id=room_id)
            return list(room.participants.values_list("id", flat=True))
        except Room.DoesNotExist:
            return []

    @database_sync_to_async
    def update_user_presence(self, is_online):
        from .models import UserPresence

        presence, created = UserPresence.objects.get_or_create(user=self.user)
        presence.is_online = is_online
        presence.save()
        return presence

    @database_sync_to_async
    def get_user_contacts(self, user_id):
        try:
            # Find all users who share a room with this user
            rooms = Room.objects.filter(participants__id=user_id)
            contacts = (
                User.objects.filter(chats__in=rooms).exclude(id=user_id).distinct()
            )
            return list(contacts.values_list("id", flat=True))
        except:
            return []


class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope.get("user")
        if not self.user or self.user.is_anonymous:
            await self.close()
            return

        self.notification_group_name = f"notify_{self.user.id}"

        # Join notification group
        await self.channel_layer.group_add(
            self.notification_group_name, self.channel_name
        )

        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "notification_group_name"):
            await self.channel_layer.group_discard(
                self.notification_group_name, self.channel_name
            )

    async def notification(self, event):
        # Send notification to WebSocket
        await self.send(text_data=json.dumps(event["payload"]))

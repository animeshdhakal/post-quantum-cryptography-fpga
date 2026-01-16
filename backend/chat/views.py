from rest_framework import generics, permissions
from .models import Room, Message
from .serializers import RoomSerializer, MessageSerializer

class RoomListView(generics.ListCreateAPIView):
    serializer_class = RoomSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Room.objects.filter(participants=self.request.user)

    def perform_create(self, serializer):
        room = serializer.save()
        room.participants.add(self.request.user)

class MessageListView(generics.ListAPIView):
    serializer_class = MessageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        room_id = self.kwargs['room_id']
        return Message.objects.filter(room__id=room_id).order_by('timestamp')

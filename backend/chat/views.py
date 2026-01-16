from rest_framework import generics, permissions, status, views
from rest_framework.response import Response
from .models import Room, Message
from .serializers import RoomSerializer, MessageSerializer
from django.contrib.auth import get_user_model

User = get_user_model()

class RoomListView(generics.ListCreateAPIView):
    serializer_class = RoomSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Room.objects.filter(participants=self.request.user)

    def perform_create(self, serializer):
        room = serializer.save()
        room.participants.add(self.request.user)

class RoomDetailView(generics.RetrieveAPIView):
    serializer_class = RoomSerializer
    permission_classes = [permissions.IsAuthenticated]
    queryset = Room.objects.all()

class JoinRoomView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            room = Room.objects.get(pk=pk)
            room.participants.add(request.user)
            return Response(RoomSerializer(room).data, status=status.HTTP_200_OK)
        except Room.DoesNotExist:
            return Response({"error": "Room not found"}, status=status.HTTP_404_NOT_FOUND)


from django.core.cache import cache
from django.core.cache.backends.base import BaseCache
from django_redis.exceptions import ConnectionInterrupted

class MessageListView(generics.ListCreateAPIView):
    serializer_class = MessageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        room_id = self.kwargs['room_id']
        
        # Query from database (cache is optional and handled gracefully)
        # If Redis is available, it will cache automatically via middleware
        # If Redis is unavailable, we just query from DB directly
        messages = Message.objects.filter(room__id=room_id).order_by('timestamp')
        
        # Optional: Try to cache for performance, but don't fail if Redis is down
        cache_key = f"messages_room_{room_id}"
        try:
            # Only cache if we have many messages (optimization)
            message_list = list(messages)
            if len(message_list) > 10:  # Only cache if there are many messages
                cache.set(cache_key, message_list, timeout=60*60)
        except (ConnectionInterrupted, Exception):
            # Redis not available, continue without caching
            pass
        
        return messages

    def perform_create(self, serializer):
        room_id = self.kwargs['room_id']
        room = Room.objects.get(pk=room_id)
        serializer.save(sender=self.request.user, room=room)
        
        # Try to invalidate cache, but don't fail if Redis is unavailable
        cache_key = f"messages_room_{room_id}"
        try:
            cache.delete(cache_key)
        except (ConnectionInterrupted, Exception) as e:
            # Redis not available, skip cache invalidation
            print(f"Cache unavailable, skipping cache delete: {e}")
            pass

class StartDirectChatView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user_id = request.data.get('user_id')
        if not user_id:
            return Response({"error": "User ID is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            other_user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)

        # Check for existing 1-on-1 room
        rooms = Room.objects.filter(participants=request.user).filter(participants=other_user)
        
        existing_room = None
        for room in rooms:
            if room.participants.count() == 2:
                existing_room = room
                break
        
        if existing_room:
            return Response(RoomSerializer(existing_room).data)
        
        # Create new room
        import uuid
        room_name = f"dm-{uuid.uuid4()}"
        
        room = Room.objects.create(name=room_name)
        room.participants.add(request.user, other_user)
        
        return Response(RoomSerializer(room).data, status=status.HTTP_201_CREATED)

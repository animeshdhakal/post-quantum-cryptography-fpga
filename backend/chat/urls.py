from django.urls import path
from .views import RoomListView, MessageListView, JoinRoomView, StartDirectChatView

urlpatterns = [
    path('rooms/', RoomListView.as_view(), name='room-list'),
    path('rooms/<int:pk>/join/', JoinRoomView.as_view(), name='room-join'),
    path('dm/', StartDirectChatView.as_view(), name='start-dm'),
    path('rooms/<int:room_id>/messages/', MessageListView.as_view(), name='message-list'),
]

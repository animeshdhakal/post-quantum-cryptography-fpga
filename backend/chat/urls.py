from .views import RoomListView, MessageListView, JoinRoomView, StartDirectChatView, RoomDetailView
from django.urls import path
urlpatterns = [
    path('rooms/', RoomListView.as_view(), name='room-list'),
    path('rooms/<int:pk>/', RoomDetailView.as_view(), name='room-detail'),
    path('rooms/<int:pk>/join/', JoinRoomView.as_view(), name='room-join'),
    path('dm/', StartDirectChatView.as_view(), name='start-dm'),
    path('rooms/<int:room_id>/messages/', MessageListView.as_view(), name='message-list'),
]

import { useState, useEffect } from 'react';
import { useAuth } from '../context/auth';
import { api } from '../api/client';
import { Link, useNavigate } from 'react-router-dom';
import { Plus, LogOut, MessageSquare, ArrowRight, Copy, Check } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { toast } from "sonner"
import {
    Card,
    CardContent,
    CardDescription,
    CardFooter,
    CardHeader,
    CardTitle,
} from "@/components/ui/card";
import {
    Dialog,
    DialogContent,
    DialogDescription,

    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from "@/components/ui/dialog";
import { Label } from '@/components/ui/label';
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

interface Room {
    id: number;
    name: string;
    created_at: string;
}

export default function ChatList() {
    const { user, logout } = useAuth();
    const [rooms, setRooms] = useState<Room[]>([]);
    const [newRoomName, setNewRoomName] = useState('');
    const [joinRoomId, setJoinRoomId] = useState('');
    const [isCreateOpen, setIsCreateOpen] = useState(false);
    const [createdRoomId, setCreatedRoomId] = useState<number | null>(null);
    const navigate = useNavigate();
    const [copied, setCopied] = useState(false);

    useEffect(() => {
        fetchRooms();
    }, []);

    const fetchRooms = async () => {
        try {
            const response = await api.get<Room[]>('/api/chat/rooms/');
            setRooms(response.data);
        } catch (error) {
            console.error("Failed to fetch rooms", error);
        }
    };

    const createRoom = async () => {
        try {
            const response = await api.post<Room>('/api/chat/rooms/', { name: newRoomName || 'Untitled Room' });
            setRooms([response.data, ...rooms]);
            setCreatedRoomId(response.data.id);
            setNewRoomName('');
            toast.success("Room created successfully!");
        } catch (error) {
            console.error("Failed to create room", error);
            toast.error("Failed to create room.");
        }
    };

    const joinRoom = async () => {
        if (!joinRoomId) return;

        try {
            // First try to join the room via API to update participants
            await api.post(`/api/chat/rooms/${joinRoomId}/join/`);
            toast.success("Joined room successfully!");
            navigate(`/chat/${joinRoomId}`);
        } catch (error) {
            console.error("Failed to join room", error);
            // If already joined or other error, still try to navigate but warn
            toast.error("Failed to join room. Please check the ID.");
        }
    };

    const copyToClipboard = (text: string) => {
        navigator.clipboard.writeText(text);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
        toast.info("Room ID copied to clipboard");
    };

    return (
        <div className="min-h-screen bg-background">
            {/* Header */}
            <header className="border-b shadow-sm sticky top-0 bg-background/80 backdrop-blur-md z-10 transition-all duration-300">
                <div className="max-w-5xl mx-auto px-4 py-4 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <div className="bg-gradient-to-br from-indigo-500 to-purple-600 p-2.5 rounded-xl shadow-lg shadow-indigo-500/20">
                            <MessageSquare className="h-5 w-5 text-white" />
                        </div>
                        <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-600 tracking-tight">SecureChat</h1>
                    </div>
                    <div className="flex items-center gap-4">
                        <div className="flex items-center gap-3 bg-muted/50 pl-1 pr-4 py-1 rounded-full border border-border/50">
                            <Avatar className="h-8 w-8 ring-2 ring-background">
                                <AvatarFallback className="bg-gradient-to-br from-blue-500 to-cyan-500 text-white font-medium">
                                    {user?.username.charAt(0).toUpperCase()}
                                </AvatarFallback>
                            </Avatar>
                            <span className="text-sm font-medium hidden sm:inline-block text-foreground/80">{user?.username}</span>
                        </div>
                        <Button variant="ghost" size="icon" onClick={() => logout()} title="Logout" className="hover:bg-red-50 hover:text-red-600 transition-colors rounded-full">
                            <LogOut className="h-5 w-5" />
                        </Button>
                    </div>
                </div>
            </header>

            <main className="max-w-5xl mx-auto px-4 py-8 space-y-8">

                {/* Actions Section */}
                <div className="grid md:grid-cols-2 gap-6">
                    {/* Create Room Card */}
                    <Card className="group relative overflow-hidden border-border/50 bg-gradient-to-br from-background via-muted/30 to-muted/50 hover:shadow-xl hover:shadow-indigo-500/10 transition-all duration-300 hover:-translate-y-1">
                        <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/5 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                        <CardHeader>
                            <CardTitle>Create New Room</CardTitle>
                            <CardDescription>Start a new encrypted conversation.</CardDescription>
                        </CardHeader>
                        <CardFooter>
                            <Dialog open={isCreateOpen} onOpenChange={(open: boolean) => {
                                setIsCreateOpen(open);
                                if (!open) setCreatedRoomId(null);
                            }}>
                                <DialogTrigger asChild>
                                    <Button className="w-full gap-2">
                                        <Plus className="h-4 w-4" /> Create Room
                                    </Button>
                                </DialogTrigger>
                                <DialogContent>
                                    <DialogHeader>
                                        <DialogTitle>Create Room</DialogTitle>
                                        <DialogDescription>
                                            Give your new chat room a name. You'll get an ID to share.
                                        </DialogDescription>
                                    </DialogHeader>

                                    {!createdRoomId ? (
                                        <div className="space-y-4 py-4">
                                            <div className="space-y-2">
                                                <Label htmlFor="name">Room Name</Label>
                                                <Input
                                                    id="name"
                                                    placeholder="e.g. Project Alpha"
                                                    value={newRoomName}
                                                    onChange={(e: React.ChangeEvent<HTMLInputElement>) => setNewRoomName(e.target.value)}
                                                />
                                            </div>
                                            <Button onClick={createRoom} className="w-full">Create</Button>
                                        </div>
                                    ) : (
                                        <div className="space-y-4 py-4">
                                            <div className="flex flex-col items-center justify-center space-y-2 text-center">
                                                <div className="p-3 bg-green-100 dark:bg-green-900 rounded-full">
                                                    <Check className="h-6 w-6 text-green-600 dark:text-green-400" />
                                                </div>
                                                <h3 className="text-lg font-semibold">Room Created!</h3>
                                                <p className="text-muted-foreground text-sm">Share this ID with your friends to let them join.</p>
                                            </div>
                                            <div className="flex items-center gap-2 bg-muted p-3 rounded-md border">
                                                <span className="font-mono text-lg flex-1 text-center font-bold tracking-wider">{createdRoomId}</span>
                                                <Button variant="ghost" size="icon" onClick={() => copyToClipboard(createdRoomId.toString())}>
                                                    {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                                                </Button>
                                            </div>
                                            <div className="flex gap-2">
                                                <Button variant="outline" className="flex-1" onClick={() => setIsCreateOpen(false)}>Close</Button>
                                                <Button className="flex-1" onClick={() => navigate(`/chat/${createdRoomId}`)}>Enter Room</Button>
                                            </div>
                                        </div>
                                    )}
                                </DialogContent>
                            </Dialog>
                        </CardFooter>
                    </Card>

                    {/* Join Room Card */}
                    <Card className="group relative overflow-hidden border-border/50 bg-gradient-to-br from-background via-muted/30 to-muted/50 hover:shadow-xl hover:shadow-purple-500/10 transition-all duration-300 hover:-translate-y-1">
                        <div className="absolute inset-0 bg-gradient-to-br from-purple-500/5 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                        <CardHeader>
                            <CardTitle>Join Room</CardTitle>
                            <CardDescription>Enter a room ID to join an existing chat.</CardDescription>
                        </CardHeader>
                        <CardContent>
                            <div className="space-y-2">
                                <Input
                                    placeholder="Room ID (e.g. 123)"
                                    value={joinRoomId}
                                    onChange={(e: React.ChangeEvent<HTMLInputElement>) => setJoinRoomId(e.target.value)}
                                    onKeyDown={(e: React.KeyboardEvent<HTMLInputElement>) => e.key === 'Enter' && joinRoom()}
                                />
                            </div>
                        </CardContent>
                        <CardFooter>
                            <Button variant="secondary" className="w-full gap-2" onClick={joinRoom} disabled={!joinRoomId}>
                                Join Chat <ArrowRight className="h-4 w-4" />
                            </Button>
                        </CardFooter>
                    </Card>
                </div>

                {/* Existing Rooms List (Optional, if API supports listing user's rooms) */}
                <div>
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                        <MessageSquare className="h-5 w-5" /> Recent Rooms
                    </h2>
                    {rooms.length === 0 ? (
                        <div className="text-center py-12 bg-muted/30 rounded-lg border border-dashed">
                            <p className="text-muted-foreground">No open chat rooms found.</p>
                        </div>
                    ) : (
                        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                            {rooms.map((room) => (
                                <Link to={`/chat/${room.id}`} key={room.id}>
                                    <Card className="hover:bg-accent/50 transition-colors cursor-pointer h-full">
                                        <CardHeader className="p-4">
                                            <CardTitle className="text-base truncate">{room.name || `Room #${room.id}`}</CardTitle>
                                            <CardDescription className="text-xs">ID: {room.id}</CardDescription>
                                        </CardHeader>
                                        <CardFooter className="p-4 pt-0 text-xs text-muted-foreground">
                                            Created: {new Date(room.created_at).toLocaleDateString()}
                                        </CardFooter>
                                    </Card>
                                </Link>
                            ))}
                        </div>
                    )}
                </div>
            </main>
        </div>
    );
}

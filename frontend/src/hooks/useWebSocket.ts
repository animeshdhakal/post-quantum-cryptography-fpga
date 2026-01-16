import { useState, useEffect, useCallback, useRef } from 'react';

export function useWebSocket(roomId: string | undefined, onMessage?: (data: any) => void) {
    const [status, setStatus] = useState<'connecting' | 'open' | 'closed'>('closed');
    const ws = useRef<WebSocket | null>(null);
    const reconnectTimeout = useRef<number | null>(null);

    const connect = useCallback(() => {
        if (!roomId) return;

        const token = localStorage.getItem('access_token');
        if (!token) return;

        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const path = roomId === 'notifications' ? 'notifications/' : `chat/${roomId}/`;
        const url = `${protocol}//localhost:8000/ws/${path}?token=${token}`;

        setStatus('connecting');
        ws.current = new WebSocket(url);

        ws.current.onopen = () => {
            console.log('WebSocket connected');
            setStatus('open');
            if (reconnectTimeout.current) {
                clearTimeout(reconnectTimeout.current);
                reconnectTimeout.current = null;
            }
        };

        ws.current.onmessage = (event) => {
            const data = JSON.parse(event.data);
            if (onMessage) {
                onMessage(data);
            }
        };

        ws.current.onclose = (event) => {
            console.log('WebSocket disconnected', event.code);
            setStatus('closed');
            // Try to reconnect after 3 seconds if not closed cleanly
            if (event.code !== 1000 && roomId) {
                reconnectTimeout.current = setTimeout(() => {
                    connect();
                }, 3000);
            }
        };

        ws.current.onerror = (error) => {
            console.error('WebSocket error', error);
            ws.current?.close();
        };
    }, [roomId, onMessage]);

    useEffect(() => {
        connect();
        return () => {
            if (ws.current) {
                ws.current.close(1000); // Clean close
            }
            if (reconnectTimeout.current) {
                clearTimeout(reconnectTimeout.current);
            }
        };
    }, [connect]);

    const sendMessage = useCallback((content: string) => {
        if (ws.current && ws.current.readyState === WebSocket.OPEN) {
            ws.current.send(JSON.stringify({ type: 'chat_message', content }));
            return true;
        }
        return false;
    }, []);

    const sendJson = useCallback((data: any) => {
        if (ws.current && ws.current.readyState === WebSocket.OPEN) {
            ws.current.send(JSON.stringify(data));
            return true;
        }
        return false;
    }, []);

    return { sendMessage, sendJson, status };
}

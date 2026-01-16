import React, { createContext, useContext, useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api/client';
import type { LoginData, RegisterData, AuthResponse, User, RegisterResponse } from '../types';
import { jwtDecode } from 'jwt-decode';

interface AuthContextType {
    user: User | null;
    loading: boolean;
    login: (data: LoginData) => Promise<void>;
    register: (data: RegisterData) => Promise<void>;
    logout: () => void;
    isAuthenticated: boolean;
    refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Internal component that has access to router context
const AuthProviderInner: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [user, setUser] = useState<User | null>(null);
    const [loading, setLoading] = useState(true);
    const navigate = useNavigate();

    // Decode token and get user info
    const getUserFromToken = (token: string): User | null => {
        try {
            const decoded: any = jwtDecode(token);
            return {
                id: decoded.user_id || decoded.id,
                username: decoded.username || decoded.email?.split('@')[0] || 'User',
                email: decoded.email || decoded.username || '',
            };
        } catch (error) {
            console.error("Invalid token", error);
            return null;
        }
    };

    // Initialize auth state from stored token
    useEffect(() => {
        const initAuth = async () => {
            const token = localStorage.getItem('access_token');
            if (token) {
                try {
                    // Try to get user from token
                    const userFromToken = getUserFromToken(token);
                    if (userFromToken) {
                        // Optionally fetch full user profile
                        try {
                            const response = await api.get<User>('/api/profile/');
                            setUser(response.data);
                        } catch (error) {
                            // If profile fetch fails, use token data
                            setUser(userFromToken);
                        }
                    }
                } catch (error) {
                    console.error("Auth initialization error", error);
                    localStorage.removeItem('access_token');
                    localStorage.removeItem('refresh_token');
                }
            }
            setLoading(false);
        };
        initAuth();
    }, []);

    const login = async (data: LoginData) => {
        try {
            const response = await api.post<AuthResponse>('/api/login/', {
                email: data.email,
                password: data.password,
            });
            
            localStorage.setItem('access_token', response.data.access);
            localStorage.setItem('refresh_token', response.data.refresh);
            
            // Set user from response or token
            if (response.data.user) {
                setUser(response.data.user);
            } else {
                const userFromToken = getUserFromToken(response.data.access);
                if (userFromToken) {
                    setUser(userFromToken);
                }
            }
            
            // Redirect to home
            navigate('/');
        } catch (error: any) {
            const errorMessage = error.response?.data?.error || 
                               error.response?.data?.detail || 
                               'Login failed. Please check your credentials.';
            throw new Error(errorMessage);
        }
    };

    const register = async (data: RegisterData) => {
        try {
            const response = await api.post<RegisterResponse>('/api/register/', {
                email: data.email,
                username: data.username || undefined,
                password: data.password,
                password_confirm: data.password_confirm,
            });
            
            localStorage.setItem('access_token', response.data.access);
            localStorage.setItem('refresh_token', response.data.refresh);
            setUser(response.data.user);
            
            // Redirect to home
            navigate('/');
        } catch (error: any) {
            const errorMessage = error.response?.data?.error || 
                               error.response?.data?.detail || 
                               error.response?.data?.email?.[0] ||
                               error.response?.data?.password?.[0] ||
                               'Registration failed. Please try again.';
            throw new Error(errorMessage);
        }
    };

    const logout = async () => {
        try {
            const refreshToken = localStorage.getItem('refresh_token');
            if (refreshToken) {
                try {
                    await api.post('/api/logout/', { refresh: refreshToken });
                } catch (error) {
                    // Continue with logout even if API call fails
                    console.error('Logout API call failed', error);
                }
            }
        } catch (error) {
            console.error('Logout error', error);
        } finally {
            localStorage.removeItem('access_token');
            localStorage.removeItem('refresh_token');
            setUser(null);
            navigate('/login');
        }
    };

    const refreshUser = async () => {
        try {
            const response = await api.get<User>('/api/profile/');
            setUser(response.data);
        } catch (error) {
            console.error('Failed to refresh user data', error);
        }
    };

    return (
        <AuthContext.Provider value={{ 
            user, 
            loading, 
            login, 
            register, 
            logout, 
            isAuthenticated: !!user,
            refreshUser 
        }}>
            {children}
        </AuthContext.Provider>
    );
};

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    return <AuthProviderInner>{children}</AuthProviderInner>;
};

export const useAuth = () => {
    const context = useContext(AuthContext);
    if (!context) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
};

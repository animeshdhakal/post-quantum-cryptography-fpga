export interface User {
    id: number;
    username: string;
    email: string;
    date_joined?: string;
    last_login?: string;
}

export interface AuthResponse {
    access: string;
    refresh: string;
    user?: User;
}

export interface RegisterData {
    email: string;
    username?: string;
    password: string;
    password_confirm: string;
}

export interface LoginData {
    email: string;
    password: string;
}

export interface RegisterResponse {
    user: User;
    access: string;
    refresh: string;
}

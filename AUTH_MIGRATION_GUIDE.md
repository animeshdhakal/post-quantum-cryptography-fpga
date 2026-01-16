# Authentication System Migration Guide

## Overview
The authentication system has been upgraded to use **email as the primary identifier** instead of username. This provides a more robust and standard authentication experience.

## Changes Made

### Backend Changes

1. **Custom User Model** (`backend/account/models.py`)
   - Created custom `User` model extending `AbstractUser`
   - Email is now the primary identifier (`USERNAME_FIELD = 'email'`)
   - Username is optional and auto-generated from email if not provided

2. **Updated Serializers** (`backend/account/serializers.py`)
   - `EmailTokenObtainPairSerializer`: Custom login serializer using email
   - `RegisterSerializer`: Enhanced with password confirmation and email validation
   - `UserSerializer`: Updated to work with custom user model
   - `ChangePasswordSerializer`: New serializer for password changes

3. **Enhanced Views** (`backend/account/views.py`)
   - `EmailTokenObtainPairView`: Login endpoint using email
   - `RegisterView`: Registration with better error handling
   - `UserProfileView`: Get/update user profile
   - `ChangePasswordView`: Change password endpoint
   - `LogoutView`: Logout with token blacklisting

4. **Updated Settings** (`backend/groot/settings.py`)
   - Added `AUTH_USER_MODEL = 'account.User'`
   - Added JWT configuration with token rotation and blacklisting
   - Added `rest_framework_simplejwt.token_blacklist` to INSTALLED_APPS

5. **Updated Chat Models** (`backend/chat/models.py`)
   - Updated to use `get_user_model()` instead of direct User import

### Frontend Changes

1. **Updated Types** (`frontend/src/types.ts`)
   - Changed `LoginData` to use `email` instead of `username`
   - Updated `RegisterData` to include `password_confirm`
   - Added `RegisterResponse` interface

2. **Enhanced Auth Context** (`frontend/src/context/auth.tsx`)
   - Email-based login and registration
   - Automatic redirect to home page after login/register
   - Better error handling and user state management
   - Token refresh handling
   - User profile fetching

3. **Updated Login Page** (`frontend/src/pages/Login.tsx`)
   - Changed from username to email input
   - Better UI with icons
   - Improved error messages

4. **Updated Register Page** (`frontend/src/pages/Register.tsx`)
   - Email as primary field
   - Username is optional
   - Password confirmation field
   - Client-side validation
   - Better error handling

## Migration Steps

### 1. Database Migration

⚠️ **IMPORTANT**: Since we're changing the User model, you'll need to:

1. **Backup your database** (if you have existing data):
   ```bash
   cd backend
   python manage.py dumpdata > backup.json
   ```

2. **Delete existing migrations** (if this is a fresh setup or you're okay losing data):
   ```bash
   rm -rf account/migrations/*
   rm -rf chat/migrations/*
   rm db.sqlite3  # Only if you're okay losing data
   ```

3. **Create new migrations**:
   ```bash
   python manage.py makemigrations
   python manage.py migrate
   ```

4. **Create superuser** (if needed):
   ```bash
   python manage.py createsuperuser
   # Use email as username
   ```

### 2. Install Dependencies

Make sure all required packages are installed:

```bash
cd backend
pip install -r requirements.txt
```

### 3. Run Migrations for Token Blacklist

```bash
python manage.py migrate token_blacklist
```

### 4. Start the Backend Server

```bash
cd backend
python manage.py runserver
```

### 5. Start the Frontend

```bash
cd frontend
pnpm install  # or npm install
pnpm dev      # or npm run dev
```

## New API Endpoints

### Authentication Endpoints

- `POST /api/login/` - Login with email and password
  - Body: `{ "email": "user@example.com", "password": "password" }`
  - Returns: `{ "access": "...", "refresh": "...", "user": {...} }`

- `POST /api/register/` - Register new user
  - Body: `{ "email": "user@example.com", "username": "optional", "password": "password", "password_confirm": "password" }`
  - Returns: `{ "user": {...}, "access": "...", "refresh": "..." }`

- `POST /api/login/refresh/` - Refresh access token
  - Body: `{ "refresh": "refresh_token" }`
  - Returns: `{ "access": "..." }`

- `GET /api/profile/` - Get current user profile
  - Requires: Bearer token
  - Returns: `{ "id": 1, "username": "...", "email": "...", ... }`

- `PATCH /api/profile/` - Update user profile
  - Requires: Bearer token
  - Body: `{ "username": "new_username" }`

- `POST /api/change-password/` - Change password
  - Requires: Bearer token
  - Body: `{ "old_password": "...", "new_password": "...", "new_password_confirm": "..." }`

- `POST /api/logout/` - Logout (blacklist token)
  - Requires: Bearer token
  - Body: `{ "refresh": "refresh_token" }`

## Features

### ✅ Email as Primary Identifier
- Users log in with their email address
- Email must be unique
- Username is optional and auto-generated if not provided

### ✅ Enhanced Security
- Password confirmation on registration
- Password validation (minimum 8 characters)
- JWT token blacklisting on logout
- Token rotation on refresh
- Automatic token refresh on 401 errors

### ✅ Better User Experience
- Automatic redirect to home after login/register
- Better error messages
- User profile management
- Password change functionality

### ✅ Standard Authentication Flow
- JWT-based authentication
- Refresh token support
- Protected routes
- Token expiration handling

## Testing

1. **Register a new user**:
   - Go to `/register`
   - Enter email, optional username, password, and confirm password
   - Should redirect to home page after successful registration

2. **Login**:
   - Go to `/login`
   - Enter email and password
   - Should redirect to home page after successful login

3. **Access Protected Routes**:
   - Try accessing `/` without logging in - should redirect to `/login`
   - After login, should be able to access protected routes

4. **Token Refresh**:
   - Wait for access token to expire (or manually remove it)
   - Make an API call - should automatically refresh token

## Troubleshooting

### Issue: Migration errors
**Solution**: Delete `db.sqlite3` and migrations, then run `makemigrations` and `migrate` again.

### Issue: "User model not found"
**Solution**: Make sure `AUTH_USER_MODEL = 'account.User'` is in `settings.py` before running migrations.

### Issue: Token blacklist errors
**Solution**: Run `python manage.py migrate token_blacklist` to create blacklist tables.

### Issue: Frontend not redirecting
**Solution**: Check browser console for errors. Make sure the auth context is properly set up.

## Notes

- Existing users will need to re-register with email
- If you have existing data, you may need to write a data migration script
- The username field is still available but optional
- Email addresses are automatically lowercased for consistency



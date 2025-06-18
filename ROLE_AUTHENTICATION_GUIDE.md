# Role-Based Authentication Guide

## Overview

The KAust app now includes a comprehensive role-based authentication system that provides different levels of access based on user roles. Users can sign in either with role-specific credentials or using Apple Sign In.

## Authentication Methods

### 1. Role-Based Password Authentication

The app supports four distinct user roles, each with specific credentials and permissions:

| Role | Username | Password | Access Level |
|------|----------|----------|--------------|
| **Owner** | `owner` | `qqq` | Full system access |
| **Administrator** | `admin` | `admin` | System management |
| **Developer** | `dev` | `dev` | Development tools |
| **Client** | `client` | `client` | Basic user access |

### 2. Apple Sign In

- Available as alternative authentication method
- Automatically assigns **Client** role by default
- Uses secure Apple ID authentication

## Role Permissions

### Client Role
- ✅ View and play songs
- ✅ Manage playlists
- ✅ Import files (limited to 50MB)
- ❌ Delete files
- ❌ Access settings
- ❌ System administration

### Developer Role  
- ✅ All Client permissions
- ✅ Delete files (development files only)
- ✅ View settings
- ✅ Access developer tools
- ❌ Manage system settings
- ❌ User management

### Administrator Role
- ✅ All Developer permissions  
- ✅ Manage settings (except owner-level)
- ✅ View analytics
- ✅ System administration (limited)
- ❌ Full system access
- ❌ Modify owner settings

### Owner Role
- ✅ Full unrestricted access
- ✅ All system features
- ✅ User management
- ✅ Complete system administration
- ✅ Override all restrictions

## Getting Started

1. **Launch the app** - You'll be presented with the sign-in screen
2. **Choose authentication method**:
   - **Role-based**: Enter username and password from the table above
   - **Apple Sign In**: Use your Apple ID (assigns Client role)
3. **Access features** based on your role permissions
4. **Sign out** when finished using the button in the top-right corner

## Features by Role

### Song Management
- **All Roles**: View, search, and play songs
- **Client+**: Add songs to playlists
- **Developer+**: Delete songs and media files
- **Admin+**: Bulk song operations

### System Access
- **Client**: Basic playback controls only
- **Developer**: Settings view access, debug tools
- **Administrator**: System settings, analytics, user management
- **Owner**: Complete system control

### File Operations
- **Client**: Import files (50MB limit)
- **Developer**: Import/delete development files
- **Administrator**: Full file management
- **Owner**: Unrestricted file operations

## Security Features

- **Session Management**: 24-hour session expiration for security
- **Permission Checking**: Real-time role verification for all features
- **Access Logging**: All access attempts are logged for security monitoring
- **Secure Storage**: Credentials and sessions are securely managed

## Troubleshooting

### Login Issues
- Verify username and password are exactly as listed in the credentials table
- Usernames are case-insensitive, passwords are case-sensitive
- Try signing out and signing in again if experiencing issues

### Permission Denied
- Check that your role has access to the requested feature
- Contact an administrator if you need elevated permissions
- Some features may have additional restrictions based on role

### Session Expired
- Sessions automatically expire after 24 hours for security
- Simply sign in again to restore access
- Your previous settings and preferences are preserved

## Technical Implementation

The authentication system follows enterprise security patterns:

- **Protocol-based architecture** for testability and modularity
- **Role hierarchy** with permission inheritance
- **Secure session management** with automatic expiration
- **Access control logging** for security auditing
- **Graceful degradation** when permissions are insufficient

## Contact

For role changes or access issues, contact your system administrator or the app owner.

---

*Last updated: December 6, 2025* 
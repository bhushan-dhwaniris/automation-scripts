# 🚀 Automation Scripts Repository

A collection of powerful automation scripts designed to simplify server management, web development, and system administration tasks. Each script is crafted for reliability, ease of use, and comprehensive functionality.

---

## 📦 Scripts Overview

### 🔄 Apache Proxy Generator
**File:** `create-apache-proxy.sh`  
**Purpose:** Automatically creates Nginx reverse proxy configurations for Apache websites with SSL support  
**Status:** ✅ Ready for Production

| Feature | Description |
|---------|-------------|
| 🔒 SSL Support | Auto-generates Let's Encrypt or self-signed certificates |
| 🌐 Multi-domain | Supports multiple domains and subdomains |
| 🛡️ Security Headers | Implements security best practices |
| 📊 Conflict Detection | Identifies and resolves server name conflicts |
| 🔧 aaPanel Integration | Works seamlessly with aaPanel configurations |
| 📝 Comprehensive Logging | Detailed access and error logs |

---

## ⚡ Quick Start

### Prerequisites
- Ubuntu/Debian Linux server
- Root or sudo access
- Nginx installed
- Apache2 installed (for proxy targets)

### Manual Installation
```bash
# Clone the repository
git clone https://github.com/yourusername/automation_scripts.git
cd automation_scripts

# Make scripts executable
sudo chmod +x *.sh

# Install to system path
sudo cp create-apache-proxy.sh /usr/local/bin/
sudo ln -s /usr/local/bin/create-apache-proxy.sh /usr/local/bin/apache-proxy
```

---

## 📖 Script Documentation

### 🔄 Apache Proxy Generator

#### Description
Creates Nginx reverse proxy configurations for Apache websites, enabling you to run multiple web applications on different ports while serving them through standard HTTP/HTTPS ports.

#### Use Cases
- **aaPanel Integration**: Proxy aaPanel Apache sites through Nginx
- **Multi-app Hosting**: Run multiple PHP applications on one server
- **SSL Termination**: Handle SSL at Nginx level for Apache backends
- **Load Balancing**: Distribute traffic across multiple Apache instances

#### Basic Usage
```bash
# HTTP only
sudo create-apache-proxy.sh example.com 8080

# With self-signed SSL
sudo create-apache-proxy.sh example.com 8080 self

# With Let's Encrypt SSL
sudo create-apache-proxy.sh example.com 8080 letsencrypt

# Using shortcut
sudo apache-proxy subdomain.example.com 8080 self
```

#### Advanced Examples
```bash
# Multiple subdomains for different services
sudo apache-proxy app.company.com 8080 letsencrypt
sudo apache-proxy blog.company.com 8081 letsencrypt
sudo apache-proxy shop.company.com 8082 letsencrypt

# Development environment
sudo apache-proxy dev.local 8080
sudo apache-proxy staging.local 8081
```

#### Configuration Files
- **Nginx Config**: `/etc/nginx/sites-available/[domain]`
- **SSL Certificates**: `/etc/ssl/certs/` or `/etc/letsencrypt/live/`
- **Log Files**: `/var/log/nginx/[domain].access.log`

#### Troubleshooting
```bash
# Check configuration
sudo nginx -t

# View logs
sudo tail -f /var/log/nginx/[domain].error.log

# Test backend directly
curl -I http://127.0.0.1:8080

# Test proxy
curl -I http://your-domain.com
```

#### Features & Benefits

| Feature | Benefit |
|---------|---------|
| **Automatic SSL** | No manual certificate management |
| **Server Name Resolution** | Prevents domain conflicts |
| **Security Headers** | Enhanced security out of the box |
| **Performance Optimization** | Optimized buffering and caching |
| **Error Handling** | Comprehensive error detection |
| **Auto-renewal** | Let's Encrypt certificates auto-renew |

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Adding New Scripts
1. **Fork** the repository
2. **Create** a new branch: `git checkout -b feature/new-script`
3. **Follow** the script template:
   ```bash
   #!/bin/bash
   # Script Name and Description
   # Created by: [Your Name]
   # Version: 1.0
   # Usage: ./script.sh [parameters]
   ```
4. **Add documentation** to this README
5. **Test thoroughly** on clean systems
6. **Submit** a pull request

### Script Requirements
- ✅ **Error handling** with proper exit codes
- ✅ **Colored output** for better UX
- ✅ **Help documentation** built-in
- ✅ **Logging capabilities**
- ✅ **Configuration validation**
- ✅ **Rollback functionality** where applicable

### Code Style Guidelines
- Use meaningful variable names
- Include comments for complex logic
- Implement proper error checking
- Follow bash best practices
- Test on multiple environments

---

## 📞 Support

### Getting Help
- 📖 **Documentation**: Check script comments and this README
- 🐛 **Issues**: Open an issue on GitHub for bugs
- 💡 **Feature Requests**: Submit enhancement requests
- 💬 **Discussions**: Join our community discussions

### Common Issues
1. **Permission Denied**: Ensure scripts are executable (`chmod +x`)
2. **Command Not Found**: Check if script is in PATH
3. **SSL Issues**: Verify domain DNS settings fo# automation-scripts
A collection of powerful automation scripts designed to simplify server management, web development, and system administration tasks. Each script is crafted for reliability, ease of use, and comprehensive functionality.
r Let's Encrypt
4. **Port Conflicts**: Check if ports are already in use

### Debugging Tips
```bash
# Enable debug mode
bash -x script.sh

# Check logs
sudo tail -f /var/log/nginx/error.log

# Validate configurations
sudo nginx -t
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**🚀 Automate Everything, Simplify Everything 🚀**

*Made with ❤️ for the DevOps community*

[![GitHub Stars](https://img.shields.io/github/stars/bhushan-dhwaniris/automation-scripts?style=social)](https://github.com/bhushan-dhwaniris/automation-scripts)
[![GitHub Forks](https://img.shields.io/github/forks/bhushan-dhwaniris/automation-scripts?style=social)](https://github.com/bhushan-dhwaniris/automation-scripts)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

</div>

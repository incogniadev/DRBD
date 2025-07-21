# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- 2025-07-21: Created dedicated docs/ directory for organized documentation
- 2025-07-21: Added comprehensive ARCHITECTURE.md with detailed system design
- 2025-07-21: Added general INSTALLATION.md guide for all Linux distributions
- 2025-07-21: Created platform-specific PROXMOX_DEBIAN.md guide

### Changed
- 2025-07-21: Refactored README.md to focus on project overview and quick start
- 2025-07-21: Improved documentation navigation with structured guide links
- 2025-07-21: Enhanced README.md with visual tables and emoji organization
- 2025-07-21: Updated floating IP address from 192.168.10.100 to 192.168.10.230 in all documentation and configuration examples
- 2025-07-21: Added specific network configuration for Docker host (Node 3) with dual IP setup:
  - Primary IP: 10.0.0.233/8 (management network)
  - Secondary IP: 192.168.10.233/24 (cluster network)
- 2025-07-21: Added Netplan configuration example for Node 3 network setup
- 2025-07-21: Updated all NFS mount references to use new floating IP 192.168.10.230
- 2025-07-21: Updated PROXMOX_DEBIAN_NOTES.md with new IP configurations and specific Node3 Docker network setup

### Removed
- 2025-07-21: Removed redundant OVERVIEW.md file (content moved to docs/ARCHITECTURE.md)
- 2025-07-21: Moved PROXMOX_DEBIAN_NOTES.md to docs/PROXMOX_DEBIAN.md
- 2025-07-21: Eliminated duplicate architecture diagrams across files
- 2025-07-21: Removed installation instructions from README.md (moved to dedicated guides)

### Fixed
- 2025-07-21: Fixed date placeholder in PROXMOX_DEBIAN_NOTES.md author section
- 2025-07-21: Resolved redundant information scattered across multiple files
- 2025-07-21: Improved language consistency across documentation

## [Initial Release]

### Added
- Initial DRBD High Availability Storage architecture documentation
- Proxmox with Debian implementation notes
- Complete installation and configuration guides
- Mermaid diagrams for system architecture
- Troubleshooting and maintenance procedures

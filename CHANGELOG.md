# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed
- 2025-07-21: Updated floating IP address from 192.168.10.100 to 192.168.10.230 in all documentation and configuration examples
- 2025-07-21: Added specific network configuration for Docker host (Node 3) with dual IP setup:
  - Primary IP: 10.0.0.233/8 (management network)
  - Secondary IP: 192.168.10.233/24 (cluster network)
- 2025-07-21: Added Netplan configuration example for Node 3 network setup
- 2025-07-21: Updated all NFS mount references to use new floating IP 192.168.10.230
- 2025-07-21: Updated PROXMOX_DEBIAN_NOTES.md with new IP configurations and specific Node3 Docker network setup

### Fixed
- 2025-07-21: Fixed date placeholder in PROXMOX_DEBIAN_NOTES.md author section

## [Initial Release]

### Added
- Initial DRBD High Availability Storage architecture documentation
- Proxmox with Debian implementation notes
- Complete installation and configuration guides
- Mermaid diagrams for system architecture
- Troubleshooting and maintenance procedures

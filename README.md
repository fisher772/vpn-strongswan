# Ipsec-Strongswan. IAC

[![GitHub](https://img.shields.io/github/v/release/fisher772/vpn-strongswan?logo=github)](https://github.com/fisher772/vpn-strongswan/releases)
[![GitHub](https://img.shields.io/badge/GitHub-Repo-blue%3Flogo%3Dgithub?logo=github&label=GitHub%20Repo)](https://github.com/fisher772/vpn-strongswan)
[![GitHub](https://img.shields.io/badge/GitHub-Repo-blue%3Flogo%3Dgithub?logo=github&label=GitHub%20Multi-Repo)](https://github.com/fisher772/docker_images)
[![GitHub](https://img.shields.io/badge/GitHub-Repo-red%3Flogo%3Dgithub?logo=github&label=GitHub%20Ansible-Repo)](https://github.com/fisher772/ansible)
[![GitHub Registry](https://img.shields.io/badge/ghrc.io-Registry-green?logo=github)](https://github.com/fisher772/vpn-strongswan/pkgs/container/vpn-strongswan)
[![Docker Registry](https://img.shields.io/badge/docker.io-Registry-green?logo=docker&logoColor=white&labelColor=blue)](https://hub.docker.com/r/fisher772/vpn-strongswan)

## All links, pointers and hints are reflected in the overview

\* You can use Ansible templates and ready-made CI/CD patterns for Jenkins and GitHub Action. 
Almost every repository contains pipeline patternsю Also integrated into the Ansible agent pipeline using its templates.


Ipsec-Strongswan is a powerful solution based on the open IPsec standard for creating VPN connections.

Why do I need a Ipsec-Strongswan?
- VPN with custom, IKEv2 L2TP protocols
- It is possible to exclude client applications or an intermediate provider in the connection
- Low connection latency
- Data protection. Reduce the risk of data leakage
- User and device authentication
- Free and Open-Source
- To interact with any restricted services or sources of information from any of the parties (Provider or Resource itself). We encrypt and mask our traffic from home, laboratory or small enterprise
- We can use a multi-level approach with multiple VPN host entry points or additionally route traffic through SQUID (you can also read about installing it in my git repository) to eliminate breadcrumbs
- Use at the router level (for example, Keenetic) to unlock your favorite services or information sources without using clients or repeatedly creating a connection profile on different devices. It is also easier to share a Wi-Fi hotspot with a guest than to disclose or collect new access for the guest.
\* An example of using a router as an IKEv1/2 client that will act as a gateway for connecting clients in a Wi-Fi coverage area or LAN network. The traffic of these clients will be directed to your VPN 
\*\* [KEENETIC MANUAL](https://help.keenetic.com/hc/ru/articles/360014239040-%D0%9A%D0%BB%D0%B8%D0%B5%D0%BD%D1%82-IKE)


This image automates the process of manual preparation, service configuration and deployment. It also follows Sec and Ops practices.

What work has been done:
- Automatic generation of self-signed certificates is configured and its regulation through variables that can be set for the manifest. You can also generate certificates through the free open certificate center service Let’s Encrypt (This is also provided), but this is for more advanced use or enterprise. Self-signed certificates are enough for our home infrastructure or lab
- Automatic generation of arbitrary connection profiles for IKEv2 and L2TP connections has been configured. These accesses can also be recreated or a number of new profiles can be formed. For your convenience, all accesses will be saved in a flat file.
- Connections are configured at a non-concurrent level, at "Asynchronous/Parallelized level" so that you can use one access profile with multiple devices or different networks.
- Adjusted optimal configuration settings for inactive session timeout
- Logging has been configured
- Integrated fail2ban

All you need to do to install Ipsec-Strongswan:
- Free ports 500/udp 4500/udp 1701/udp
- Change the env_example file to .env and set the variable values ​​in the .env file.
- Have free resources on the host/hosts
- Deploy docker compose manifest

Environment:

A more detailed explanation of the variables can be found in the git repository: vpn_l2tp-ikev2/env_example


Commands:

```bash
# To delete current access profiles
sudo sleep 30 && docker exec -it ./entrypoint.sh --clean_creds

# To create new access profiles
sudo sleep 30 && docker exec -it ./entrypoint.sh --adduser
```

\* Flat files with accesses can be viewed inside the container: /etc/ipsec.d/ipsec.docker/users_creds/*.txt
\*\* Or inside a mounted volume on the host: volumes: ipsec.d

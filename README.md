# Oasis Sapphire Multi-Wallet Deploy Script

![Banner](https://img.shields.io/badge/Hardhat-Oasis%20Sapphire-blue?style=for-the-badge&logo=ethereum)  
**Automate Smart Contract Deployment to Oasis Sapphire Testnet with Multi-Wallet Support**

Selamat datang di **Oasis Sapphire Multi-Wallet Deploy Script**! Script ini dirancang untuk mempermudah Anda dalam mendeploy smart contract ke Oasis Sapphire Testnet menggunakan Hardhat, dengan dukungan untuk multiple wallets dalam satu kali eksekusi. Cocok untuk developer blockchain yang ingin menguji kontrak dari berbagai akun atau mendistribusikan deployment secara otomatis.

## ✨ Fitur Utama
- **Multi-Wallet Support**: Deploy kontrak dari beberapa wallet sekaligus hanya dengan satu script.
- **Otomatisasi Penuh**: Dari instalasi dependensi hingga deployment, semuanya dilakukan secara otomatis.
- **Hardhat Integration**: Menggunakan Hardhat untuk kompilasi dan deployment yang andal.
- **User-Friendly**: Antarmuka CLI interaktif untuk memasukkan jumlah wallet dan private keys.
- **Oasis Sapphire Testnet**: Dikonfigurasi khusus untuk jaringan Oasis Sapphire Testnet (`chainId: 23295`).

## 🚀 Cara Kerja
Script ini akan:
1. Menginstal Node.js, npm, dan Hardhat jika belum ada.
2. Membuat proyek Hardhat di direktori lokal.
3. Meminta Anda memasukkan jumlah wallet dan private keys.
4. Menulis smart contract `TokenAuthority` (ERC20) dan script deployment.
5. Mendeploy kontrak dari setiap wallet ke Oasis Sapphire Testnet.
6. Menampilkan alamat kontrak dan tautan ke explorer untuk setiap deployment.

## 📋 Persyaratan
Sebelum menjalankan script, pastikan Anda memiliki:
- **Sistem Operasi**: Linux (Ubuntu direkomendasikan), macOS, atau WSL di Windows.
- **Internet**: Untuk mengunduh dependensi.
- **Private Keys**: Minimal satu private key dengan dana TEST di Oasis Sapphire Testnet ([Faucet](https://faucet.testnet.sapphire.oasis.io/)).
- **Terminal**: Akses ke command line interface.

## 🛠️ Instalasi dan Penggunaan

### 1. Clone Repository
```bash
git clone https://github.com/fznrival/Deployment.git
```

```bash
cd oasis
```

### 2. Berikan izin eksekusi
```bash
chmod +x oasis-multi.sh
```

### 3. Jalankan Script
```bash
./oasis-multi.sh
```

### 📜 Struktur Proyek
Setelah script dijalankan, direktori hardhat-project akan dibuat dengan struktur berikut:

- hardhat-project/
- ├── contracts/
- │   └── TokenAuthority.sol  # Kontrak ERC20 sederhana
- ├── scripts/
- │   └── deploy.js           # Script deployment multi-wallet
- ├── .env                    # File konfigurasi (private keys, RPC, dll.)
- ├── hardhat.config.js       # Konfigurasi Hardhat
- └── node_modules/           # Dependensi npm

### ⚙️ Konfigurasi
Script menggunakan Oasis Sapphire Testnet secara default:

```bash
RPC URL: https://testnet.sapphire.oasis.io
Chain ID: 23295
Explorer: https://testnet.explorer.sapphire.oasis.io
```

Untuk mengubah jaringan atau kontrak, edit file .env atau modifikasi hardhat.config.js dan contracts/TokenAuthority.sol sesuai kebutuhan.

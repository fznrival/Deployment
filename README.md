
# Auto Deploy Smart Contract - Funki Testnet

Script Bash ini digunakan untuk otomatisasi proses deployment smart contract ke **Funki Testnet**. Dengan sekali eksekusi, script akan menangani kompilasi, deployment, dan verifikasi smart contract, sehingga mempermudah pengujian di jaringan Funki.

## 🚀 Fitur
- ✅ **Otomatisasi Full Deployment** – Kompilasi dan deploy smart contract dengan satu perintah.
- ✅ **Integrasi dengan RPC Funki Testnet** – Menyediakan koneksi langsung ke node RPC Funki.
- ✅ **Multi-Contract Deployment** – Mendukung deployment beberapa smart contract dalam satu eksekusi.
- ✅ **Logging & Error Handling** – Menyimpan log untuk debugging yang lebih mudah.

## 📋 Persyaratan
- **Bash (Unix/Linux/macOS)**
- **Node.js & NPM** (untuk dependency smart contract)
- **Solidity Compiler (`solc` atau `Hardhat`/`Foundry`)**
- **Private Key & RPC URL** (Konfigurasi di `.env`)

## 🔧 Cara Penggunaan

### 1️⃣ Clone Repository
```bash
git clone https://github.com/fznrival/Deployment.git && cd Deployment
```
### 4️⃣ Permission Script Deployment
```bash
chmod +x funki.sh
```

### 4️⃣ Jalankan Script Deployment
```bash
./funki.sh
```

## 📜 Lisensi
MIT License


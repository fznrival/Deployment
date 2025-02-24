# **Automated Hardhat Deployment Script**  

## **Deskripsi**  
Script ini digunakan untuk mengotomatisasi deployment kontrak ERC-20 menggunakan Hardhat ke berbagai jaringan blockchain. Skrip mencakup fitur-fitur berikut:  

✅ Instalasi dependensi secara otomatis (Node.js, Hardhat, OpenZeppelin)  
✅ Deteksi dan konfigurasi jaringan berdasarkan `rpc.json`  
✅ Multi-wallet deployment dengan pemilihan jumlah akun  
✅ Opsi pengiriman token ke alamat acak atau daftar penerima (`penerima.txt`)  
✅ Mekanisme retry jika deployment gagal  
✅ Countdown otomatis antar deployment  

## **Prasyarat**  
Sebelum menjalankan skrip, pastikan sistem telah memiliki:  
- **Ubuntu/Debian-based OS**  
- **Bash Shell**  
- **jq** (akan diinstal otomatis jika belum tersedia)  
- **Node.js & npm** (jika belum ada, akan diinstal otomatis)  

## **Cara Penggunaan**  

### **1. Siapkan File Konfigurasi**  
- **rpc.json**: berisi daftar jaringan dan RPC endpoint yang akan digunakan  
- **penerima.txt** *(opsional)*: daftar alamat yang akan menerima token jika dipilih opsi pengiriman ke file
```bash
git clone https://github.com/fznrival/Deployment.git
```

### **2. Jalankan Script**  
```bash  
cd Deployment && chmod +x deployment.sh && ./deployment.sh  
```

### **3. Ikuti Instruksi di Terminal**  
- Masukkan jumlah wallet dan private key  
- Pilih metode pengiriman token  
- Masukkan nama dan simbol token  

### **4. Proses Deployment**  
- Script akan menginisialisasi proyek Hardhat  
- Menulis kontrak ERC-20  
- Mengonfigurasi jaringan dan memverifikasi konektivitas  
- Melakukan deployment ke setiap jaringan sesuai jumlah yang diatur  

## **Struktur Proyek**  
```  
/project-directory  
│── deployment.sh  
│── rpc.json  
│── penerima.txt (opsional)  
│── /hardhat-project  
│   ├── contracts/  
│   │   └── TokenAuthority.sol  
│   ├── scripts/  
│   │   └── deploy.js  
│   ├── hardhat.config.js  
│   ├── .env  
```  

## **Catatan Tambahan**  
- Jika terjadi kegagalan saat deployment, script akan mencoba kembali hingga 3 kali sebelum melanjutkan ke jaringan berikutnya.  
- Pengiriman token dapat dilakukan ke alamat acak atau berdasarkan daftar dari `penerima.txt`.  
- Deployment dilakukan secara berkala sesuai jumlah yang telah ditentukan dengan jeda 24 jam antar deployment.  


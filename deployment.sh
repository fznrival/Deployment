#!/bin/bash

# Warna untuk output
BLUE='\033[0;34m'
WHITE='\033[0;97m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RESET='\033[0m'

# Direktori skrip saat ini
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit

# Fungsi untuk menampilkan timestamp
log_timestamp() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${RESET} $1"
}

# Fungsi countdown
countdown() {
    local seconds=$1
    while [ $seconds -gt 0 ]; do
        echo -ne "\r${YELLOW}Countdown to next deployment: $(date -u -d "@$seconds" +%H:%M:%S)${RESET}"
        sleep 1
        : $((seconds--))
    done
    echo
}

# Fungsi untuk menghasilkan alamat acak (dummy untuk testnet)
generate_random_address() {
    # Menggunakan openssl untuk menghasilkan 20 byte acak (40 hex chars) dengan prefix 0x
    echo "0x$(openssl rand -hex 20)"
}

# Fungsi instalasi dependensi
install_dependencies() {
    log_timestamp "${YELLOW}Menginstal dependensi...${RESET}"

    if ! command -v node &> /dev/null; then
        log_timestamp "${YELLOW}Node.js belum terinstal. Menginstal Node.js...${RESET}"
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if ! command -v npm &> /dev/null; then
        sudo apt-get install -y npm
    fi

    if ! command -v npx &> /dev/null || ! npx hardhat --version &> /dev/null; then
        log_timestamp "${YELLOW}Menginstal Hardhat...${RESET}"
        npm install -g hardhat
    fi
}

# Fungsi untuk menginisialisasi proyek Hardhat
init_hardhat_project() {
    if [ ! -d "$SCRIPT_DIR/hardhat-project" ]; then
        log_timestamp "${YELLOW}Menginisialisasi proyek Hardhat...${RESET}"
        mkdir hardhat-project
        cd hardhat-project || exit
        npx hardhat init <<EOF
y
0
y
y
y
EOF
        npm install --save-dev @nomiclabs/hardhat-ethers ethers
        npm install @openzeppelin/contracts
        npm install dotenv
    else
        cd hardhat-project || exit
    fi
}

# Fungsi untuk mengatur input pengguna
configure_inputs() {
    if [ ! -f ".env" ]; then
        read -p "Masukkan RPC URL : " RPC_URL
        if [ -z "$RPC_URL" ]; then
            log_timestamp "${RED}RPC URL wajib diisi!${RESET}"
            exit 1
        fi

        read -p "Masukkan Chain ID : " CHAIN_ID
        if ! [[ "$CHAIN_ID" =~ ^[0-9]+$ ]]; then
            log_timestamp "${RED}Chain ID harus berupa angka!${RESET}"
            exit 1
        fi

        read -p "Masukkan Explorer URL : " EXPLORER_URL
        if [ -z "$EXPLORER_URL" ]; then
            log_timestamp "${RED}Explorer URL wajib diisi!${RESET}"
            exit 1
        fi

        read -p "Masukkan jumlah wallet yang akan digunakan: " NUM_WALLETS
        if ! [[ "$NUM_WALLETS" =~ ^[0-9]+$ ]] || [ "$NUM_WALLETS" -lt 1 ]; then
            log_timestamp "${RED}Jumlah wallet harus berupa angka positif!${RESET}"
            exit 1
        fi

        # Array untuk menyimpan private keys
        declare -a PRIVATE_KEYS
        for ((i=1; i<=NUM_WALLETS; i++)); do
            read -p "Masukkan Private Key untuk Wallet #$i: " PRIVATE_KEY
            if [ -z "$PRIVATE_KEY" ]; then
                log_timestamp "${RED}Private Key untuk Wallet #$i wajib diisi!${RESET}"
                exit 1
            fi
            PRIVATE_KEYS+=("$PRIVATE_KEY")
        done

        read -p "Berapa kali deployment yang diinginkan? " DEPLOY_COUNT
        if ! [[ "$DEPLOY_COUNT" =~ ^[0-9]+$ ]] || [ "$DEPLOY_COUNT" -lt 1 ]; then
            log_timestamp "${RED}Jumlah deployment harus berupa angka positif!${RESET}"
            exit 1
        fi

        read -p "Apakah ingin mengirim token ke alamat acak setelah deploy? (y/n): " SEND_TO_RANDOM
        if [[ "$SEND_TO_RANDOM" != "y" && "$SEND_TO_RANDOM" != "n" ]]; then
            log_timestamp "${RED}Jawaban harus 'y' atau 'n'!${RESET}"
            exit 1
        fi

        # Tulis ke .env dengan format JSON array
        {
            echo "RPC_URL=\"$RPC_URL\""
            echo "EXPLORER_URL=\"$EXPLORER_URL\""
            echo "CHAIN_ID=\"$CHAIN_ID\""
            echo "DEPLOY_COUNT=$DEPLOY_COUNT"
            echo "SEND_TO_RANDOM=\"$SEND_TO_RANDOM\""
            echo -n "PRIVATE_KEYS=["
            for ((i=0; i<${#PRIVATE_KEYS[@]}; i++)); do
                echo -n "\"${PRIVATE_KEYS[$i]}\""
                [ $i -lt $((${#PRIVATE_KEYS[@]}-1)) ] && echo -n ","
            done
            echo "]"
        } > .env

        # Verifikasi isi .env
        log_timestamp "${YELLOW}Isi .env yang dibuat:${RESET}"
        cat .env
    fi
}

# Fungsi untuk menulis kontrak dan script deploy
write_contract_and_script() {
    log_timestamp "${YELLOW}Menulis kontrak dan script deploy...${RESET}"

    mkdir -p contracts
    mkdir -p scripts

    # Tulis kontrak TokenAuthority dengan fungsi transfer
    cat <<EOL > contracts/TokenAuthority.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenAuthority is ERC20 {
    constructor() ERC20("KRNL Token", "KRNL") {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1 juta token dengan 18 desimal
    }
}
EOL

    # Tulis script deploy untuk multi wallet dan transfer ke random address
    cat <<EOL > scripts/deploy.js
const hre = require("hardhat");

async function main() {
  const signers = await hre.ethers.getSigners();
  
  if (!process.env.PRIVATE_KEYS) {
    throw new Error("PRIVATE_KEYS not found in .env");
  }

  console.log("PRIVATE_KEYS from .env:", process.env.PRIVATE_KEYS);
  if (signers.length === 0) {
    throw new Error("No accounts found. Please check your private keys in .env");
  }

  console.log("Deploying contracts with multiple wallets...");
  for (let i = 0; i < signers.length; i++) {
    const wallet = signers[i];
    console.log(\`Deploying from wallet #\${i + 1}: \${wallet.address}\`);
    
    const TokenAuthority = await hre.ethers.getContractFactory("TokenAuthority", wallet);
    const tokenAuthority = await TokenAuthority.deploy();
    
    await tokenAuthority.deployed();
    console.log(\`TokenAuthority deployed to: \${tokenAuthority.address} by wallet #\${i + 1}\`);

    if (process.env.SEND_TO_RANDOM === "y") {
      const randomAddress = "0x" + Math.random().toString(16).slice(2, 42).padEnd(40, '0');
      console.log(\`Sending 1000 tokens to random address: \${randomAddress}\`);
      const tx = await tokenAuthority.transfer(randomAddress, ethers.utils.parseEther("1000"));
      await tx.wait();
      console.log(\`Transfer successful: \${tx.hash}\`);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOL

    # Konfigurasi hardhat.config.js untuk multi wallet
    cat <<EOL > hardhat.config.js
require("@nomiclabs/hardhat-ethers");
require('dotenv').config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    custom: {
      url: process.env.RPC_URL,
      accounts: JSON.parse(process.env.PRIVATE_KEYS || '[]'),
      chainId: parseInt(process.env.CHAIN_ID),
    }
  }
};
EOL
}

# Fungsi untuk deploy kontrak
deploy_contract() {
    log_timestamp "${YELLOW}Mengkompilasi dan deploy kontrak...${RESET}"
    npx hardhat compile || { log_timestamp "${RED}Kompilasi gagal.${RESET}"; exit 1; }
    DEPLOY_OUTPUT=$(npx hardhat run scripts/deploy.js --network custom)
    if [ $? -ne 0 ]; then
        log_timestamp "${RED}Deployment gagal.${RESET}"
        exit 1
    fi

    log_timestamp "${YELLOW}Hasil deployment:${RESET}"
    echo "$DEPLOY_OUTPUT" | while IFS= read -r line; do
        if [[ "$line" =~ "TokenAuthority deployed to:" ]]; then
            CONTRACT_ADDRESS=$(echo "$line" | grep -oP 'TokenAuthority deployed to: \K(0x[a-fA-F0-9]{40})')
            WALLET_NUM=$(echo "$line" | grep -oP 'wallet #\K[0-9]+')
            log_timestamp "${YELLOW}Kontrak dari wallet #$WALLET_NUM di-deploy di: $CONTRACT_ADDRESS${RESET}"
            log_timestamp "${WHITE}Lihat kontrak di: ${BLUE}$EXPLORER_URL/address/$CONTRACT_ADDRESS${RESET}"
        elif [[ "$line" =~ "Transfer successful:" ]]; then
            TX_HASH=$(echo "$line" | grep -oP 'Transfer successful: \K(0x[a-fA-F0-9]+)')
            log_timestamp "${WHITE}Transfer tx: ${BLUE}$EXPLORER_URL/tx/$TX_HASH${RESET}"
        fi
    done
}

# Fungsi utama dengan loop terbatas dan countdown
main() {
    install_dependencies
    init_hardhat_project
    configure_inputs

    # Baca DEPLOY_COUNT dari .env
    source .env
    deploy_iteration=0

    while [ $deploy_iteration -lt $DEPLOY_COUNT ]; do
        ((deploy_iteration++))
        log_timestamp "${YELLOW}Memulai deployment ke-$deploy_iteration dari $DEPLOY_COUNT${RESET}"
        write_contract_and_script
        deploy_contract
        if [ $deploy_iteration -lt $DEPLOY_COUNT ]; then
            log_timestamp "Menunggu 24 jam untuk deploy berikutnya..."
            countdown 86400  # 86400 detik = 24 jam
        fi
    done
    log_timestamp "${GREEN}Semua deployment selesai (${DEPLOY_COUNT} kali)!${RESET}"
}

# Menangani sinyal interrupt (Ctrl+C)
trap 'echo -e "\n${RED}Script dihentikan oleh user${RESET}"; exit 0' INT

# Eksekusi program
main

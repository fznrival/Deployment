#!/bin/bash

# Warna untuk output
BLUE='\033[0;34m'
WHITE='\033[0;97m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
MAGENTA='\033[0;95m'
RESET='\033[0m'

# Direktori skrip saat ini
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit

# Pastikan jq terinstal
if ! command -v jq &> /dev/null; then
    log_timestamp "${YELLOW}Menginstal jq...${RESET}"
    sudo apt-get install -y jq
fi

# Fungsi untuk menampilkan header
display_header() {
    clear
    echo -e "${MAGENTA}====================================${RESET}"
    echo -e "${MAGENTA}=        Auto Deployment Bot       =${RESET}"
    echo -e "${MAGENTA}=        Created by fznrival       =${RESET}"
    echo -e "${MAGENTA}=       https://t.me/fznrival      =${RESET}"
    echo -e "${MAGENTA}====================================${RESET}"
    echo ""
    echo ""
    echo ""
}

# Fungsi untuk menampilkan timestamp
log_timestamp() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${RESET} $1"
}

# Fungsi untuk check network connectivity
check_network_connectivity() {
    local rpc_url=$1
    local domain=$(echo "$rpc_url" | sed -E 's#https?://([^/]+).*#\1#')
    
    log_timestamp "${YELLOW}Checking network connectivity to $domain...${RESET}"
    
    if ping -c 1 -W 5 "$domain" &> /dev/null; then
        log_timestamp "${GREEN}Network connectivity OK${RESET}"
        return 0
    fi
    
    if curl --connect-timeout 10 -sI "$rpc_url" &> /dev/null; then
        log_timestamp "${GREEN}RPC endpoint reachable${RESET}"
        return 0
    fi
    
    log_timestamp "${RED}Cannot connect to RPC endpoint $rpc_url. Skipping this network.${RESET}"
    return 1
}

# Fungsi countdown
countdown() {
    local seconds=$1
    while [ $seconds -gt 0 ]; do
        echo -ne "\r${YELLOW}Countdown to next deployment: $(date -u -d "@$seconds" +%H:%M:%S)${RESET}"
        sleep 1
        ((seconds--))
    done
    echo
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

# Fungsi untuk mengatur konfigurasi untuk satu jaringan
configure_network() {
    local rpc_url=$1
    local chain_id=$2
    local explorer_url=$3
    local network_name=$4

    log_timestamp "${YELLOW}Mengatur konfigurasi untuk jaringan: $network_name${RESET}"

    if ! check_network_connectivity "$rpc_url"; then
        return 1
    fi

    {
        echo "RPC_URL=\"$rpc_url\""
        echo "EXPLORER_URL=\"$explorer_url\""
        echo "CHAIN_ID=\"$chain_id\""
        echo "DEPLOY_COUNT=$DEPLOY_COUNT"
        echo "SEND_TO_RANDOM=\"$SEND_TO_RANDOM\""
        echo "SEND_TO_FILE=\"$SEND_TO_FILE\""
        echo -n "PRIVATE_KEYS=["
        for ((i=0; i<${#PRIVATE_KEYS[@]}; i++)); do
            echo -n "\"${PRIVATE_KEYS[$i]}\""
            [ $i -lt $((${#PRIVATE_KEYS[@]}-1)) ] && echo -n ","
        done
        echo "]"
    } > .env

    log_timestamp "${YELLOW}Isi .env untuk $network_name:${RESET}"
    cat .env
    return 0
}

# Fungsi untuk menulis kontrak dan script deploy
write_contract_and_script() {
    log_timestamp "${YELLOW}Menulis kontrak ERC1155 dan script deploy dengan nama token: $TOKEN_NAME (${TOKEN_SYMBOL})...${RESET}"

    mkdir -p contracts
    mkdir -p scripts

    cat <<EOL > contracts/TokenAuthority.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TokenAuthority is ERC1155 {
    uint256 public constant MAIN_TOKEN = 0;
    
    constructor() ERC1155("https://api.example.com/metadata/{id}.json") {
        _mint(msg.sender, MAIN_TOKEN, 1000000 * 10**18, "");
    }
}
EOL

    cat <<'EOL' > scripts/deploy.js
const hre = require("hardhat");
const { ethers } = require("ethers");

async function main() {
  const signers = await hre.ethers.getSigners();
  
  if (!process.env.PRIVATE_KEYS) {
    throw new Error("PRIVATE_KEYS not found in .env");
  }

  console.log("PRIVATE_KEYS from .env:", process.env.PRIVATE_KEYS);
  if (signers.length === 0) {
    throw new Error("No accounts found. Please check your private keys in .env");
  }

  console.log("Deploying ERC1155 contracts with multiple wallets...");
  for (let i = 0; i < signers.length; i++) {
    const wallet = signers[i];
    console.log(`Deploying from wallet #${i + 1}: ${wallet.address}`);
    
    const TokenAuthority = await hre.ethers.getContractFactory("TokenAuthority", wallet);
    const tokenAuthority = await TokenAuthority.deploy();
    
    await tokenAuthority.deployed();
    console.log(`TokenAuthority deployed to: ${tokenAuthority.address} by wallet #${i + 1}`);

    if (process.env.SEND_TO_RANDOM === "y") {
      const randomWallet = ethers.Wallet.createRandom();
      const randomAddress = randomWallet.address;
      const randomPrivateKey = randomWallet.privateKey;
      console.log(`Sending 1000 tokens (ID: 0) to random address: ${randomAddress}`);
      console.log(`Random private key: ${randomPrivateKey}`);
      const tx = await tokenAuthority.safeTransferFrom(
        wallet.address,
        randomAddress,
        0, // Token ID
        ethers.utils.parseEther("1000"),
        "0x"
      );
      await tx.wait();
      console.log(`Transfer successful: ${tx.hash}`);
    }

    if (process.env.SEND_TO_FILE === "y") {
      const fs = require("fs");
      const recipients = fs.readFileSync("../penerima.txt", "utf8").split("\n").filter(line => line.trim() !== "");
      for (const recipient of recipients) {
        const address = recipient.split(",")[0].trim();
        if (address.match(/^0x[a-fA-F0-9]{40}$/)) {
          console.log(`Sending 1000 tokens (ID: 0) to address from file: ${address}`);
          const tx = await tokenAuthority.safeTransferFrom(
            wallet.address,
            address,
            0, // Token ID
            ethers.utils.parseEther("1000"),
            "0x"
          );
          await tx.wait();
          console.log(`Transfer successful: ${tx.hash}`);
        } else {
          console.log(`Invalid address in penerima.txt: ${address}. Skipping...`);
        }
      }
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

    cat <<'EOL' > hardhat.config.js
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

# Fungsi untuk deploy kontrak dengan retry mechanism
deploy_contract() {
    local max_retries=3
    local retry_count=0
    local retry_delay=30

    while [ $retry_count -lt $max_retries ]; do
        log_timestamp "${YELLOW}Mengkompilasi dan deploy kontrak (Percobaan $((retry_count + 1))/${max_retries})...${RESET}"
        
        npx hardhat compile || { 
            log_timestamp "${RED}Kompilasi gagal.${RESET}"
            return 1
        }

        if DEPLOY_OUTPUT=$(npx hardhat run scripts/deploy.js --network custom 2>&1); then
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

            # Simpan private key dari alamat acak ke penerima.txt
            if [ "$SEND_TO_RANDOM" = "y" ]; then
                echo "$DEPLOY_OUTPUT" | while IFS= read -r line; do
                    if [[ "$line" =~ "Sending 1000 tokens (ID: 0) to random address:" ]]; then
                        RANDOM_ADDRESS=$(echo "$line" | grep -oP 'Sending 1000 tokens \(ID: 0\) to random address: \K(0x[a-fA-F0-9]{40})')
                        RANDOM_PK=$(echo "$DEPLOY_OUTPUT" | grep -oP 'Random private key: \K(0x[a-fA-F0-9]{64})')
                        if [ -n "$RANDOM_ADDRESS" ] && [ -n "$RANDOM_PK" ]; then
                            log_timestamp "${YELLOW}Menyimpan private key untuk $RANDOM_ADDRESS ke penerima.txt${RESET}"
                            echo "$RANDOM_ADDRESS,$RANDOM_PK" >> "$SCRIPT_DIR/penerima.txt"
                        fi
                    fi
                done
            fi

            return 0
        else
            log_timestamp "${RED}Deployment gagal dengan error:${RESET}"
            echo "$DEPLOY_OUTPUT"
            
            if [[ "$DEPLOY_OUTPUT" =~ "ETIMEDOUT" ]] || [[ "$DEPLOY_OUTPUT" =~ "ENETUNREACH" ]]; then
                ((retry_count++))
                if [ $retry_count -lt $max_retries ]; then
                    log_timestamp "${YELLOW}Menunggu $retry_delay detik sebelum mencoba lagi...${RESET}"
                    sleep $retry_delay
                    continue
                fi
            else
                log_timestamp "${RED}Error bukan timeout. Membatalkan deployment untuk jaringan ini.${RESET}"
                return 1
            fi
        fi
    done

    log_timestamp "${RED}Deployment gagal setelah $max_retries percobaan.${RESET}"
    return 1
}

# Fungsi utama dengan loop untuk semua jaringan
main() {
    display_header
    install_dependencies
    init_hardhat_project

    if [ ! -f "$SCRIPT_DIR/rpc.json" ]; then
        log_timestamp "${RED}File rpc.json tidak ditemukan di $SCRIPT_DIR!${RESET}"
        exit 1
    fi

    NETWORK_COUNT=$(jq -r '. | length' "$SCRIPT_DIR/rpc.json")
    log_timestamp "${YELLOW}Menemukan $NETWORK_COUNT jaringan di rpc.json${RESET}"

    read -p "Masukkan jumlah wallet yang akan digunakan: " NUM_WALLETS
    if ! [[ "$NUM_WALLETS" =~ ^[0-9]+$ ]] || [ "$NUM_WALLETS" -lt 1 ]; then
        log_timestamp "${RED}Jumlah wallet harus berupa angka positif!${RESET}"
        exit 1
    fi

    declare -a PRIVATE_KEYS
    for ((i=1; i<=NUM_WALLETS; i++)); do
        read -p "Masukkan Private Key untuk Wallet #$i: " PRIVATE_KEY
        if [ -z "$PRIVATE_KEY" ]; then
            log_timestamp "${RED}Private Key untuk Wallet #$i wajib diisi!${RESET}"
            exit 1
        fi
        PRIVATE_KEYS+=("$PRIVATE_KEY")
    done

    read -p "Berapa kali deployment yang diinginkan per jaringan? " DEPLOY_COUNT
    if ! [[ "$DEPLOY_COUNT" =~ ^[0-9]+$ ]] || [ "$DEPLOY_COUNT" -lt 1 ]; then
        log_timestamp "${RED}Jumlah deployment harus berupa angka positif!${RESET}"
        exit 1
    fi

    echo "Pilih metode pengiriman token setelah deploy:"
    echo "1. Kirim ke alamat acak"
    echo "2. Kirim ke alamat dari file penerima.txt"
    echo "3. Tidak mengirim (skip)"
    read -p "Masukkan pilihan (1/2/3): " SEND_OPTION
    
    # Inisialisasi variabel default
    SEND_TO_RANDOM="n"
    SEND_TO_FILE="n"
    
    case $SEND_OPTION in
        1)
            SEND_TO_RANDOM="y"
            ;;
        2)
            SEND_TO_FILE="y"
            if [ ! -f "$SCRIPT_DIR/penerima.txt" ]; then
                log_timestamp "${RED}File penerima.txt tidak ditemukan di $SCRIPT_DIR!${RESET}"
                exit 1
            fi
            ;;
        3)
            # Tidak ada tindakan, skip pengiriman
            ;;
        *)
            log_timestamp "${RED}Pilihan harus 1, 2, atau 3!${RESET}"
            exit 1
            ;;
    esac

    read -p "Masukkan nama token: " TOKEN_NAME
    if [ -z "$TOKEN_NAME" ]; then
        log_timestamp "${RED}Nama token wajib diisi! Menggunakan default 'Rivalz Nexus'${RESET}"
        TOKEN_NAME="Rivalz Nexus"
    fi
    if [[ "$TOKEN_NAME" =~ ^\$.* ]]; then
        log_timestamp "${RED}Nama token tidak boleh berupa placeholder seperti \$TOKEN_NAME!${RESET}"
        exit 1
    fi

    read -p "Masukkan simbol token: " TOKEN_SYMBOL
    if [ -z "$TOKEN_SYMBOL" ]; then
        log_timestamp "${RED}Simbol token wajib diisi! Menggunakan default 'RNS'${RESET}"
        TOKEN_SYMBOL="RNS"
    fi
    if [[ "$TOKEN_SYMBOL" =~ ^\$.* ]]; then
        log_timestamp "${RED}Simbol token tidak boleh berupa placeholder seperti \$TOKEN_SYMBOL!${RESET}"
        exit 1
    fi

    for ((network_index=0; network_index<NETWORK_COUNT; network_index++)); do
        RPC_URL=$(jq -r ".[$network_index].rpcUrl" "$SCRIPT_DIR/rpc.json")
        CHAIN_ID=$(jq -r ".[$network_index].chainId" "$SCRIPT_DIR/rpc.json")
        EXPLORER_URL=$(jq -r ".[$network_index].explorer" "$SCRIPT_DIR/rpc.json")
        NETWORK_NAME=$(jq -r ".[$network_index].name" "$SCRIPT_DIR/rpc.json")

        if [ "$RPC_URL" == "null" ] || [ "$CHAIN_ID" == "null" ] || [ "$EXPLORER_URL" == "null" ]; then
            log_timestamp "${RED}Data tidak lengkap untuk jaringan #$((network_index + 1)) di rpc.json. Melewati...${RESET}"
            continue
        fi

        log_timestamp "${YELLOW}Memproses jaringan: $NETWORK_NAME${RESET}"

        if configure_network "$RPC_URL" "$CHAIN_ID" "$EXPLORER_URL" "$NETWORK_NAME"; then
            deploy_iteration=0

            while [ $deploy_iteration -lt $DEPLOY_COUNT ]; do
                ((deploy_iteration++))
                log_timestamp "${YELLOW}Memulai deployment ke-$deploy_iteration dari $DEPLOY_COUNT untuk $NETWORK_NAME${RESET}"
                write_contract_and_script
                deploy_contract || {
                    log_timestamp "${RED}Deployment gagal untuk $NETWORK_NAME. Melanjutkan ke jaringan berikutnya...${RESET}"
                    break
                }
                if [ $deploy_iteration -lt $DEPLOY_COUNT ]; then
                    log_timestamp "Menunggu 24 jam untuk deploy berikutnya di $NETWORK_NAME..."
                    countdown 86400
                fi
            done
            log_timestamp "${GREEN}Selesai deployment untuk $NETWORK_NAME (${DEPLOY_COUNT} kali)${RESET}"
        else
            log_timestamp "${RED}Konfigurasi gagal untuk $NETWORK_NAME. Melewati jaringan ini.${RESET}"
        fi

        if [ $network_index -lt $((NETWORK_COUNT - 1)) ]; then
            log_timestamp "${YELLOW}Menunggu 10 detik sebelum memproses jaringan berikutnya...${RESET}"
            countdown 10
        fi
    done

    log_timestamp "${GREEN}Semua jaringan selesai diproses!${RESET}"
}

# Menangani sinyal interrupt (Ctrl+C)
trap 'echo -e "\n${RED}Script dihentikan oleh user${RESET}"; exit 0' INT

# Eksekusi program
main

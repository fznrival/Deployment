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

# Fungsi untuk menghitung waktu tunggu sampai eksekusi berikutnya
calculate_next_run() {
    local current_timestamp=$(date +%s)
    local next_run=$((current_timestamp + 86400)) # 86400 detik = 24 jam
    echo "$next_run"
}

# Fungsi instalasi dependensi
install_dependencies() {
    log_timestamp "${YELLOW}Menginstal dependensi...${RESET}"

    if [ ! -d ".git" ]; then
        log_timestamp "${YELLOW}Menginisialisasi repository Git...${RESET}"
        git init
    fi

    if ! command -v forge &> /dev/null; then
        log_timestamp "${YELLOW}Foundry belum terinstal. Menginstal Foundry...${RESET}"
        curl -L https://foundry.paradigm.xyz | bash
        source ~/.foundry/bin/init.sh
    fi

    if [ ! -d "$SCRIPT_DIR/lib/openzeppelin-contracts" ]; then
        log_timestamp "${YELLOW}Menginstal OpenZeppelin Contracts...${RESET}"
        git clone https://github.com/OpenZeppelin/openzeppelin-contracts.git "$SCRIPT_DIR/lib/openzeppelin-contracts"
    fi
}

# Fungsi validasi input
validate_input() {
    local input="$1"
    if [[ "$input" =~ [\"\'\\] ]]; then
        log_timestamp "${RED}Input tidak boleh mengandung tanda kutip atau backslash.${RESET}"
        exit 1
    fi
}

# Fungsi input detail
input_required_details() {
    if [ ! -f "$SCRIPT_DIR/token_deployment/.env" ]; then
        read -p "Masukkan Nama Token (default: Rivalz Funki): " TOKEN_NAME
        TOKEN_NAME="${TOKEN_NAME:-Rivalz Funki}"
        validate_input "$TOKEN_NAME"

        read -p "Masukkan Simbol Token (default: RLF): " TOKEN_SYMBOL
        TOKEN_SYMBOL="${TOKEN_SYMBOL:-RLF}"
        validate_input "$TOKEN_SYMBOL"

        read -p "Jumlah kontrak yang akan dideploy (default: 1): " NUM_CONTRACTS
        NUM_CONTRACTS="${NUM_CONTRACTS:-1}"

        read -p "Masukkan Private Key Anda: " PRIVATE_KEY
        if [ -z "$PRIVATE_KEY" ]; then
            log_timestamp "${RED}Private Key wajib diisi!${RESET}"
            exit 1
        fi

        read -p "Masukkan RPC URL (default: https://funki-testnet.alt.technology): " RPC_URL
        RPC_URL="${RPC_URL:-https://funki-testnet.alt.technology}"

        read -p "Masukkan Explorer URL (default: https://testnet.funkiscan.io): " EXPLORER_URL
        EXPLORER_URL="${EXPLORER_URL:-https://testnet.funkiscan.io}"

        read -p "Masukkan Alamat Anda (public address): " YOUR_ADDRESS
        if [ -z "$YOUR_ADDRESS" ]; then
            log_timestamp "${RED}Alamat Anda wajib diisi!${RESET}"
            exit 1
        fi

        mkdir -p "$SCRIPT_DIR/token_deployment"
        cat <<EOL > "$SCRIPT_DIR/token_deployment/.env"
PRIVATE_KEY="$PRIVATE_KEY"
TOKEN_NAME="$TOKEN_NAME"
TOKEN_SYMBOL="$TOKEN_SYMBOL"
NUM_CONTRACTS="$NUM_CONTRACTS"
RPC_URL="$RPC_URL"
EXPLORER_URL="$EXPLORER_URL"
YOUR_ADDRESS="$YOUR_ADDRESS"
EOL

        cat <<EOL > "$SCRIPT_DIR/foundry.toml"
[profile.default]
src = "src"
out = "out"
libs = ["lib"]

[rpc_endpoints]
rpc_url = "$RPC_URL"
EOL
    fi
}

# Fungsi deploy kontrak
deploy_contract() {
    source "$SCRIPT_DIR/token_deployment/.env"
    mkdir -p "$SCRIPT_DIR/src"

    cat <<EOL > "$SCRIPT_DIR/src/Rivalz_Funki.sol"
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Rivalz is ERC20 {
    constructor() ERC20("${TOKEN_NAME}", "${TOKEN_SYMBOL}") {
        _mint(msg.sender, 1000000000 * (10 ** decimals()));
    }
}
EOL

    forge build || { log_timestamp "${RED}Kompilasi gagal.${RESET}"; exit 1; }

    for i in $(seq 1 "$NUM_CONTRACTS"); do
        log_timestamp "${YELLOW}Mengambil nonce terbaru untuk alamat Anda...${RESET}"

        RAW_NONCE=$(curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_getTransactionCount","params":["'"$YOUR_ADDRESS"'", "pending"],"id":1}' \
            "$RPC_URL" | jq -r '.result')

        if [[ "$RAW_NONCE" =~ ^0x[0-9a-fA-F]+$ ]]; then
            NONCE=$((16#${RAW_NONCE#0x}))
        else
            log_timestamp "${RED}Invalid nonce value received: $RAW_NONCE${RESET}"
            exit 1
        fi

        log_timestamp "${YELLOW}Nonce untuk kontrak ke-$i: $NONCE${RESET}"

        DEPLOY_OUTPUT=$(forge create "$SCRIPT_DIR/src/Rivalz_Funki.sol:Rivalz" \
            --rpc-url "$RPC_URL" \
            --private-key "$PRIVATE_KEY" \
            --chain-id 3397901 \
            --nonce "$NONCE" \
            --legacy \
            --broadcast)

        if [[ $? -ne 0 ]]; then
            log_timestamp "${RED}Deploy kontrak ke-$i gagal.${RESET}"
            continue
        fi

        CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP 'Deployed to: \K(0x[a-fA-F0-9]{40})')
        log_timestamp "${YELLOW}Kontrak ke-$i berhasil di-deploy di alamat: $CONTRACT_ADDRESS${RESET}"
        log_timestamp "${WHITE}Lihat kontrak di: ${BLUE}$EXPLORER_URL/address/$CONTRACT_ADDRESS${RESET}"
    done
}

# Fungsi utama dengan loop
main_loop() {
    install_dependencies
    input_required_details

    while true; do
        log_timestamp "Memulai deployment batch baru"
        deploy_contract
        
        next_run=$(calculate_next_run)
        current_time=$(date +%s)
        sleep_duration=$((next_run - current_time))
        
        log_timestamp "Deployment selesai. Menunggu 24 jam untuk batch berikutnya..."
        log_timestamp "Waktu eksekusi berikutnya: $(date -d "@$next_run" '+%Y-%m-%d %H:%M:%S')"
        
        sleep "$sleep_duration"
    done
}

# Menangani sinyal interrupt (Ctrl+C)
trap 'echo -e "\n${RED}Script dihentikan oleh user${RESET}"; exit 0' INT

# Eksekusi program
main_loop

#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Vault + SoftHSM + 자가서명 인증서 + 완전 자동화 스크립트 (오류 감지 강화)
# 사용법: bash scripts/setup_vault_softhsm.sh
# ---------------------------------------------------------------------------

set -euo pipefail

# [설정값]
VAULT_DOCKER_DIR="./infra/docker/vault"
SOFTHSM_DOCKER_DIR="./infra/docker/softhsm"
VAULT_CERTS_DIR="$VAULT_DOCKER_DIR/certs"
SOFTHSM_TOKENS_DIR="$SOFTHSM_DOCKER_DIR/tokens"
SOFTHSM_CONF="$SOFTHSM_DOCKER_DIR/softhsm2.conf"
SOFTHSM_SLOT="0"
SOFTHSM_LABEL="vault"
SOFTHSM_PIN="1234"
VAULT_KEY_LABEL="vault-hsm-key"
VAULT_HCL="$VAULT_DOCKER_DIR/vault.hcl"
VAULT_CERT="$VAULT_CERTS_DIR/vault.crt"
VAULT_KEY="$VAULT_CERTS_DIR/vault.key"
VAULT_CN="localhost"
CERT_DAYS=730

echo -e "\n===[1/7] 폴더 생성 및 초기화"
sudo mkdir -p "$VAULT_CERTS_DIR" "$SOFTHSM_TOKENS_DIR"
sudo chown -R $USER:$USER "$VAULT_DOCKER_DIR" "$SOFTHSM_DOCKER_DIR"

echo -e "\n===[2/7] SoftHSM2 conf 파일 자동 생성"
cat > "$SOFTHSM_CONF" <<EOF
directories.tokendir = $SOFTHSM_TOKENS_DIR
objectstore.backend = file
EOF

# SOFTHSM2_CONF 환경변수 자동 지정
export SOFTHSM2_CONF="$SOFTHSM_CONF"

if [ ! -f "$SOFTHSM_CONF" ]; then
    echo "[ERROR] SoftHSM2 conf 파일이 존재하지 않습니다: $SOFTHSM_CONF"
    exit 1
fi

echo -e "\n[INFO] SOFTHSM2_CONF 환경변수: $SOFTHSM2_CONF"
# 환경변수 적용 상태 확인
if ! env | grep -q "SOFTHSM2_CONF"; then
    echo "[WARN] SOFTHSM2_CONF 환경변수가 적용되지 않았습니다."
    exit 1
fi

echo -e "\n===[3/7] SoftHSM 토큰/슬롯 초기화"
# 소프트 HSM 토큰 생성(이미 있으면 스킵)
if ! SOFTHSM2_CONF="$SOFTHSM_CONF" softhsm2-util --show-slots | grep -q "$SOFTHSM_LABEL"; then
    SOFTHSM2_CONF="$SOFTHSM_CONF" softhsm2-util --init-token --slot "$SOFTHSM_SLOT" --label "$SOFTHSM_LABEL" --pin "$SOFTHSM_PIN" --so-pin "987654"
    if [ $? -ne 0 ]; then
        echo "[ERROR] SoftHSM 토큰 초기화 중 conf 파일을 인식하지 못했습니다."
        echo "[TIP] conf 경로가 맞는지, 퍼미션이 올바른지, 환경변수가 제대로 지정됐는지 확인하세요."
        exit 1
    fi
else
    echo "[INFO] 기존 토큰 존재, 생성 생략"
fi

echo -e "\n===[4/7] Vault 자가서명 인증서 발급"
if [ ! -f "$VAULT_CERT" ] || [ ! -f "$VAULT_KEY" ]; then
    openssl req -x509 -nodes -days "$CERT_DAYS" \
      -newkey rsa:2048 \
      -keyout "$VAULT_KEY" \
      -out "$VAULT_CERT" \
      -subj "/CN=$VAULT_CN"
    echo "[INFO] 인증서/키 생성 완료"
else
    echo "[INFO] 인증서/키 파일 이미 존재, 스킵"
fi



echo -e "\n===[6/7] Docker Compose 샘플 안내"
cat <<EOC
다음 docker-compose.yml 예시로 Vault/SoftHSM 연동 가능:
-----------------------------------------------
services:
  softhsm:
    image: softhsm2:latest
    environment:
      - SOFTHSM2_CONF=/etc/softhsm/softhsm2.conf
    volumes:
      - $SOFTHSM_TOKENS_DIR:/softhsm/tokens
      - $SOFTHSM_CONF:/etc/softhsm/softhsm2.conf
  vault:
    image: vault:latest
    depends_on: [softhsm]
    cap_add: [IPC_LOCK]
    environment:
      - VAULT_LOCAL_CONFIG_PATH=/vault/vault.hcl
      - SOFTHSM2_CONF=/etc/softhsm/softhsm2.conf
    ports: [ "8200:8200" ]
    volumes:
      - $VAULT_DOCKER_DIR/file:/vault/file
      - $VAULT_CERTS_DIR:/vault/certs
      - $VAULT_HCL:/vault/vault.hcl
      - $SOFTHSM_TOKENS_DIR:/softhsm/tokens
      - $SOFTHSM_CONF:/etc/softhsm/softhsm2.conf
-----------------------------------------------
(이미지 버전/볼륨 경로 등은 환경에 맞게 수정)
EOC

echo -e "\n===[7/7] 준비 완료: docker compose up -d로 Vault/SoftHSM 자동화 기동 가능!"

echo -e "\n🚀 [완료] Vault + SoftHSM 자동화 준비가 모두 끝났습니다!"

#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# vault/init.sh : Vault 볼륨/설정/인증서/권한 초기화 (인증서 항상 새로 생성, 발행자/부서 정보 포함)
# ------------------------------------------------------------------------------

set -euo pipefail

VAULT_DIR=./docker/vault
VAULT_UID=100
VAULT_GID=100

# 인증서 subject 정보(원하는 값으로 수정!)
ORG="YourOrganization"
ORG_UNIT="DevOpsTeam"
COUNTRY="KR"
CITY="Seoul"
STATE="Seoul"
CN="localhost"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${RED}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# 1. 필수 디렉토리 생성
info "[1/7] Vault 볼륨/설정/인증서/로그 폴더 생성"
sudo mkdir -p $VAULT_DIR/config $VAULT_DIR/file $VAULT_DIR/certs $VAULT_DIR/logs

# 2. vault.hcl 템플릿 복사/치환
if [ ! -f $VAULT_DIR/vault.hcl ]; then
    info "[2/7] vault.hcl 템플릿 복사"
    sudo cp ./templates/vault/vault.hcl $VAULT_DIR/vault.hcl
    sudo chown $VAULT_UID:$VAULT_GID $VAULT_DIR/vault.hcl
    sudo chmod 640 $VAULT_DIR/vault.hcl
else
    info "[2/7] vault.hcl 이미 존재 (생략)"
fi

# 3. Vault 인증서(자가서명) 항상 새로 생성 및 덮어쓰기 (발행자, 부서 포함)
CERT_KEY=${VAULT_DIR}/certs/vault.key
CERT_CRT=${VAULT_DIR}/certs/vault.crt

info "[3/7] Vault 자가서명 인증서/키 새로 생성(기존 파일 덮어쓰기, 발행자/부서 정보 포함)"
sudo openssl req -x509 -newkey rsa:2048 \
  -keyout "$CERT_KEY" \
  -out "$CERT_CRT" \
  -days 730 \
  -nodes \
  -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$ORG_UNIT/CN=$CN"
sudo chown $VAULT_UID:$VAULT_GID "$CERT_KEY" "$CERT_CRT"
sudo chmod 640 "$CERT_KEY" "$CERT_CRT"
CRT_TIME=$(stat -c %y "$CERT_CRT")
info "[3/7] Vault 자가서명 인증서/키 새로 생성 및 덮어쓰기 완료: $CRT_TIME"

# 4. 인증서 subject/issuer 정보 즉시 출력
info "[4/7] 인증서 Subject/Issuer 정보:"
openssl x509 -in "$CERT_CRT" -noout -subject -issuer

# 5. 전체 권한 재설정
info "[5/7] Vault 전체 폴더/파일 권한 일괄 적용"
sudo chown -R $VAULT_UID:$VAULT_GID $VAULT_DIR
sudo chmod -R 750 $VAULT_DIR

# 6. 적용 결과 ls -l로 상세 표시
info "[6/7] Vault 디렉토리 구조 및 권한(적용 결과)"
sudo ls -lR $VAULT_DIR

info "[7/7] Vault 볼륨/설정/인증서/권한 초기화 및 결과 표시 완료!"

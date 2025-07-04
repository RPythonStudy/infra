#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# 00_cleanup.sh : 기존 컨테이너, 네트워크, 임시 docker 폴더 삭제 (data는 보존)
# ------------------------------------------------------------------------------

set -euo pipefail

SERVICES="elk keycloak vault openldap elasticsearch logstash kibana filebeat softhsm"
DOCKER_DIR=./docker
DATA_DIR=./data

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${RED}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

info "기존 컨테이너(동작/중지 불문) 자동 삭제"
for c in $SERVICES; do
    if sudo docker ps -a --format '{{.Names}}' | grep -qw "$c"; then
        info "기존 $c 컨테이너 발견, 삭제 진행"
        sudo docker rm -f "$c"
    fi
done

info "기존 infra_ 네트워크 자동 삭제"
for net in $(sudo docker network ls --format '{{.Name}}' | grep '^infra_'); do
    info "네트워크 $net 삭제"
    sudo docker network rm "$net" || warn "$net 삭제 실패(이미 없음)"
done

# 컨테이너 삭제 후, 남아있는 컨테이너 목록 보여주기
info "=== [컨테이너 삭제 후, 남아있는 전체 컨테이너 목록] ==="
sudo docker ps -a

# docker 폴더 유무 및 내용 표시
if [ -d "$DOCKER_DIR" ]; then
    info "$DOCKER_DIR 디렉토리(존재) - 내용:"
    ls -l "$DOCKER_DIR"
    info "$DOCKER_DIR 디렉토리 삭제"
    sudo rm -rf "$DOCKER_DIR"
    info "$DOCKER_DIR 디렉토리 삭제 완료"
else
    info "$DOCKER_DIR 디렉토리 없음"
fi

# data 폴더 유무 및 내용 표시
if [ -d "$DATA_DIR" ]; then
    info "$DATA_DIR(데이터) 폴더(존재) - 내용:"
    ls -l "$DATA_DIR"
    info "$DATA_DIR(데이터) 폴더는 보존합니다."
else
    info "$DATA_DIR 폴더 없음"
fi

info "[완료] 초기화 작업 종료."

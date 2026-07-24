#!/bin/bash
# =============================================================================
# restore_build_cache.sh - 统一构建缓存恢复脚本（iOS + Android）
# =============================================================================
# 用途: 从 pods-cache 恢复所有需要网络下载的构建依赖，避免 flutter clean 后
#       或更换设备时因网络问题导致构建失败。
#
# 恢复内容:
#   1. sqlite3 预编译 dylib (iOS)       — GitHub Releases，国内极易超时
#   2. Gradle 发行版 zip (Android)       — services.gradle.org，下载较慢
#
# 不需要缓存的（已有镜像源或CDN加速）:
#   - CocoaPods 依赖 (ios/Pods/)        — pod install 从 CDN 下载，通常可用
#   - Maven 依赖 (JAR/AAR)              — 已配置阿里云镜像，通常可用
#   - Flutter SDK / Dart SDK             — 属于系统级安装，不在项目范围内
#
# 用法:
#   chmod +x scripts/restore_build_cache.sh
#   ./scripts/restore_build_cache.sh           # 恢复全部
#   ./scripts/restore_build_cache.sh --ios     # 仅恢复 iOS
#   ./scripts/restore_build_cache.sh --android # 仅恢复 Android
#   ./scripts/restore_build_cache.sh --check   # 仅检查缓存状态
#
# 详见: docs/developer/design/code-knowledge-base/build-environment-troubleshooting-V1.0.md
# =============================================================================

set -euo pipefail

# 项目根目录（脚本所在目录的上一级）
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PODS_CACHE_DIR="${PROJECT_ROOT}/pods-cache"
GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step()  { echo -e "${BLUE}[STEP]${NC} $1"; }

# -----------------------------------------------------------------------------
# 参数解析
# -----------------------------------------------------------------------------
RESTORE_IOS=true
RESTORE_ANDROID=true
CHECK_ONLY=false

for arg in "$@"; do
    case $arg in
        --ios)     RESTORE_ANDROID=false ;;
        --android) RESTORE_IOS=false ;;
        --check)   CHECK_ONLY=true; RESTORE_IOS=false; RESTORE_ANDROID=false ;;
        --help|-h)
            echo "用法: $0 [--ios|--android|--check|--help]"
            echo "  无参数  恢复全部缓存"
            echo "  --ios   仅恢复 iOS 缓存"
            echo "  --android 仅恢复 Android 缓存"
            echo "  --check 仅检查缓存状态"
            exit 0
            ;;
        *)
            error "未知参数: $arg (使用 --help 查看用法)"
            exit 1
            ;;
    esac
done

echo ""
echo "========================================"
echo "  VidLang 构建缓存恢复工具"
echo "========================================"
echo "  项目路径: ${PROJECT_ROOT}"
echo "  缓存路径: ${PODS_CACHE_DIR}"
echo ""

# =============================================================================
# 1. 检查 pods-cache 目录
# =============================================================================
if [ ! -d "${PODS_CACHE_DIR}" ]; then
    error "pods-cache 目录不存在: ${PODS_CACHE_DIR}"
    error "请参照知识库文档创建该目录并放入缓存文件"
    exit 1
fi

# =============================================================================
# 2. 检查模式
# =============================================================================
if [ "$CHECK_ONLY" = true ]; then
    step "检查缓存状态"

    echo ""
    echo "--- iOS: sqlite3 预编译 dylib ---"
    SQLITE3_DIR="${PODS_CACHE_DIR}/sqlite3"
    if [ -d "${SQLITE3_DIR}" ]; then
        for f in "${SQLITE3_DIR}"/*; do
            if [ -f "$f" ]; then
                hash=$(shasum -a 256 "$f" | awk '{print $1}')
                size=$(du -h "$f" | awk '{print $1}')
                echo "  ✅ $(basename "$f")  (${size}, sha256: ${hash:0:16}...)"
            fi
        done
    else
        echo "  ❌ 目录不存在: ${SQLITE3_DIR}"
    fi

    echo ""
    echo "--- Android: Gradle 发行版 ---"
    GRADLE_DIR="${PODS_CACHE_DIR}/gradle"
    if [ -d "${GRADLE_DIR}" ]; then
        for f in "${GRADLE_DIR}"/*; do
            if [ -f "$f" ]; then
                size=$(du -h "$f" | awk '{print $1}')
                echo "  ✅ $(basename "$f")  (${size})"
            fi
        done
    else
        echo "  ❌ 目录不存在: ${GRADLE_DIR}"
    fi

    echo ""
    info "检查完成。使用 $0 (无参数) 执行恢复。"
    exit 0
fi

# =============================================================================
# 3. 恢复 iOS: sqlite3 预编译 dylib
# =============================================================================
if [ "$RESTORE_IOS" = true ]; then
    step "恢复 iOS: sqlite3 预编译 dylib"

    SQLITE3_CACHE="${PODS_CACHE_DIR}/sqlite3"
    HOOKS_CACHE="${PROJECT_ROOT}/.dart_tool/hooks_runner/shared/sqlite3/build"

    # sqlite3 3.5.0 的 SHA256 哈希前8位（来自 asset_hashes.dart）
    declare -A FILE_HASH_MAP=(
        ["libsqlite3.arm64.ios.dylib"]="14ddadc3"
        ["libsqlite3.arm64.ios_sim.dylib"]="1ef1f54d"
    )

    if [ ! -d "${SQLITE3_CACHE}" ]; then
        warn "pods-cache/sqlite3 目录不存在，跳过 iOS sqlite3 恢复"
    else
        mkdir -p "${HOOKS_CACHE}"
        restored=0
        skipped=0

        for filename in "${!FILE_HASH_MAP[@]}"; do
            hash_prefix="${FILE_HASH_MAP[$filename]}"
            source_file="${SQLITE3_CACHE}/${filename}"
            target_dir="${HOOKS_CACHE}/download-${hash_prefix}"
            target_file="${target_dir}/libsqlite3.dylib"

            if [ ! -f "${source_file}" ]; then
                warn "源文件不存在，跳过: ${filename}"
                continue
            fi

            if [ -f "${target_file}" ]; then
                # 验证哈希
                actual_hash=$(shasum -a 256 "${target_file}" | awk '{print $1}')
                source_hash=$(shasum -a 256 "${source_file}" | awk '{print $1}')
                if [ "${actual_hash}" = "${source_hash}" ]; then
                    info "缓存已存在且有效，跳过: ${filename}"
                    skipped=$((skipped + 1))
                    continue
                fi
            fi

            mkdir -p "${target_dir}"
            cp "${source_file}" "${target_file}"

            # 验证复制后的哈希
            actual_hash=$(shasum -a 256 "${target_file}" | awk '{print $1}')
            source_hash=$(shasum -a 256 "${source_file}" | awk '{print $1}')
            if [ "${actual_hash}" = "${source_hash}" ]; then
                info "恢复成功: ${filename} → download-${hash_prefix}/"
                restored=$((restored + 1))
            else
                error "哈希不匹配: ${filename}"
                rm -f "${target_file}"
                exit 1
            fi
        done

        echo ""
        info "iOS sqlite3: ${restored} 个文件已恢复, ${skipped} 个文件已存在"
    fi
fi

# =============================================================================
# 4. 恢复 Android: Gradle 发行版
# =============================================================================
if [ "$RESTORE_ANDROID" = true ]; then
    step "恢复 Android: Gradle 发行版"

    GRADLE_CACHE="${PODS_CACHE_DIR}/gradle"

    # 从 gradle-wrapper.properties 读取 Gradle 版本和 URL
    WRAPPER_PROPS="${PROJECT_ROOT}/android/gradle/wrapper/gradle-wrapper.properties"
    if [ ! -f "${WRAPPER_PROPS}" ]; then
        warn "gradle-wrapper.properties 不存在，跳过 Gradle 恢复"
    else
        # 解析 distributionUrl
        DIST_URL=$(grep "distributionUrl" "${WRAPPER_PROPS}" | sed 's/distributionUrl=//' | sed 's/\\//g' | tr -d '[:space:]')
        # 提取文件名（如 gradle-9.1.0-all.zip）
        DIST_FILENAME=$(basename "${DIST_URL}")
        # 提取版本目录名（如 gradle-9.1.0-all）
        DIST_DIRNAME=$(echo "${DIST_FILENAME}" | sed 's/\.zip$//')

        # Gradle wrapper 的哈希目录名是 URL 的 MD5 哈希的 Base36 编码
        # 我们通过查找已有目录来确定，或者计算
        GRADLE_DIST_BASE="${GRADLE_USER_HOME}/wrapper/dists/${DIST_DIRNAME}"

        source_zip="${GRADLE_CACHE}/${DIST_FILENAME}"

        if [ ! -f "${source_zip}" ]; then
            warn "Gradle zip 不存在于缓存: ${source_zip}"
            warn "如需缓存，请下载: ${DIST_URL}"
        else
            # 查找或创建目标哈希目录
            if [ -d "${GRADLE_DIST_BASE}" ]; then
                # 找到已有的哈希目录
                HASH_DIR=$(ls -d "${GRADLE_DIST_BASE}"/*/ 2>/dev/null | head -1)
                if [ -z "${HASH_DIR}" ]; then
                    # 目录存在但没有子目录，需要创建
                    # Gradle wrapper 哈希计算比较复杂，这里使用已知的值或让 Gradle 自动处理
                    warn "Gradle 分发目录存在但无哈希子目录: ${GRADLE_DIST_BASE}"
                    warn "将 zip 复制到临时位置，Gradle 首次运行时会自动处理"
                    # 放置 zip 到基础目录下，Gradle 会自动计算哈希并提取
                    cp "${source_zip}" "${GRADLE_DIST_BASE}/${DIST_FILENAME}"
                    info "已复制 Gradle zip 到: ${GRADLE_DIST_BASE}/"
                    info "Gradle 首次运行时会自动提取"
                else
                    HASH_DIR="${HASH_DIR%/}"
                    target_zip="${HASH_DIR}/${DIST_FILENAME}"

                    if [ -f "${target_zip}" ]; then
                        info "Gradle zip 已存在，跳过: ${HASH_DIR}"
                    else
                        cp "${source_zip}" "${target_zip}"
                        # 删除 .ok 和 .lck 标记文件，让 Gradle 重新提取
                        rm -f "${HASH_DIR}/${DIST_FILENAME}.ok" "${HASH_DIR}/${DIST_FILENAME}.lck" 2>/dev/null
                        info "恢复成功: ${DIST_FILENAME} → ${HASH_DIR}/"
                        info "Gradle 首次运行时会自动提取"
                    fi
                fi
            else
                # 目录不存在，需要创建
                warn "Gradle 分发目录不存在: ${GRADLE_DIST_BASE}"
                warn "Gradle wrapper 将在首次构建时自动下载"
                warn "如需离线使用，请先在能联网的设备上运行一次 ./gradlew --version"
            fi
        fi
    fi
fi

# =============================================================================
# 5. 汇总
# =============================================================================
echo ""
echo "========================================"
step "恢复完成"
echo "========================================"
echo ""
echo "后续步骤:"
echo "  1. flutter pub get"
if [ "$RESTORE_IOS" = true ]; then
    echo "  2. cd ios && pod install --repo-update && cd ..  (iOS CocoaPods)"
fi
if [ "$RESTORE_ANDROID" = true ]; then
    echo "  3. cd android && ./gradlew --version && cd ..    (Android Gradle)"
fi
echo "  4. flutter run -d <device-id>"
echo ""

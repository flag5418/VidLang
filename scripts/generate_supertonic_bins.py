#!/usr/bin/env python3
"""
预先生成 Supertonic TTS 所需的 .bin 文件

用法:
    cd /path/to/vidlang
    python3 scripts/generate_supertonic_bins.py

生成文件:
    models/supertonic/onnx/unicode_indexer.bin
    models/supertonic/voice.bin

这些文件需要作为资产打包到应用中，避免在启动时进行转换。
"""

import json
import struct
import sys
from pathlib import Path


def generate_unicode_indexer_bin(json_path: Path, bin_path: Path) -> None:
    """将 unicode_indexer.json 转换为 .bin 格式（int32 数组，小端序）"""
    print(f"转换 unicode_indexer: {json_path} -> {bin_path}")
    
    with open(json_path, "r", encoding="utf-8") as f:
        arr = json.load(f)
    
    if not isinstance(arr, list):
        raise ValueError(f"JSON must be an array of integers, got {type(arr)}")
    
    # 验证所有元素都是整数
    for i, x in enumerate(arr):
        if not isinstance(x, int) or isinstance(x, bool):
            raise ValueError(f"JSON element {i} is not an integer: {x} (type={type(x)})")
        if x < -2**31 or x > 2**31 - 1:
            raise ValueError(f"JSON element {i} out of int32 range: {x}")
    
    # 写入小端序 int32 数组
    with open(bin_path, "wb") as f:
        for x in arr:
            f.write(struct.pack("<i", x))
    
    print(f"  成功: {len(arr)} 个 int32 -> {bin_path}")


def flatten_nested(data):
    """递归展平嵌套数组"""
    result = []
    for item in data:
        if isinstance(item, list):
            result.extend(flatten_nested(item))
        else:
            result.append(float(item))
    return result


def load_one_voice_json(json_path: Path) -> tuple:
    """加载单个 voice style JSON 文件"""
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    if "style_ttl" not in data:
        raise ValueError(f"{json_path}: missing key 'style_ttl'")
    if "style_dp" not in data:
        raise ValueError(f"{json_path}: missing key 'style_dp'")
    
    style_ttl = data["style_ttl"]
    style_dp = data["style_dp"]
    
    if "dims" not in style_ttl or "data" not in style_ttl:
        raise ValueError(f"{json_path}: 'style_ttl' must contain keys 'dims' and 'data'")
    
    ttl_dims = tuple(int(x) for x in style_ttl["dims"])
    # 展平嵌套数组
    ttl_data = flatten_nested(style_ttl["data"])
    
    ttl_size = 1
    for d in ttl_dims:
        ttl_size *= d
    if len(ttl_data) != ttl_size:
        raise ValueError(
            f"{json_path}: ttl size {len(ttl_data)} != prod(ttl_dims) {ttl_size} (ttl_dims={ttl_dims})"
        )
    
    if "dims" not in style_dp or "data" not in style_dp:
        raise ValueError(f"{json_path}: 'style_dp' must contain keys 'dims' and 'data'")
    
    dp_dims = tuple(int(x) for x in style_dp["dims"])
    # 展平嵌套数组
    dp_data = flatten_nested(style_dp["data"])
    
    dp_size = 1
    for d in dp_dims:
        dp_size *= d
    if len(dp_data) != dp_size:
        raise ValueError(
            f"{json_path}: dp size {len(dp_data)} != prod(dp_dims) {dp_size} (dp_dims={dp_dims})"
        )
    
    return ttl_dims, ttl_data, dp_dims, dp_data


def merge_voices_to_bin(voice_styles_dir: Path, bin_path: Path) -> None:
    """将 voice_styles/*.json 合并为 voice.bin"""
    print(f"合并 voice styles: {voice_styles_dir}/*.json -> {bin_path}")
    
    json_files = sorted(voice_styles_dir.glob("*.json"))
    if not json_files:
        raise ValueError(f"No JSON files found in {voice_styles_dir}")
    
    ttl_arrays = []
    dp_arrays = []
    ref_ttl = ref_dp = None
    
    for p in json_files:
        ttl_dims, ttl_arr, dp_dims, dp_arr = load_one_voice_json(p)
        
        if len(ttl_dims) != 3 or ttl_dims[0] != 1:
            raise ValueError(f"{p}: expected ttl dims [1, d1, d2], got {ttl_dims}")
        if len(dp_dims) != 3 or dp_dims[0] != 1:
            raise ValueError(f"{p}: expected dp dims [1, d1, d2], got {dp_dims}")
        
        if ref_ttl is None:
            ref_ttl, ref_dp = ttl_dims, dp_dims
        elif ttl_dims[1:] != ref_ttl[1:] or dp_dims[1:] != ref_dp[1:]:
            raise ValueError(
                f"File {p} has dims ttl{ttl_dims} dp{dp_dims}; "
                f"expected ttl[1:]={ref_ttl[1:]}, dp[1:]={ref_dp[1:]}"
            )
        
        ttl_arrays.append(ttl_arr)
        dp_arrays.append(dp_arr)
    
    n = len(json_files)
    
    # 合并数据
    ttl_stack = []
    for arr in ttl_arrays:
        ttl_stack.extend(arr)
    dp_stack = []
    for arr in dp_arrays:
        dp_stack.extend(arr)
    
    out_ttl_dims = [n, ref_ttl[1], ref_ttl[2]]
    out_dp_dims = [n, ref_dp[1], ref_dp[2]]
    
    with open(bin_path, "wb") as f:
        # 写入维度 (int64, 小端序)
        for d in out_ttl_dims:
            f.write(struct.pack("<q", d))
        for d in out_dp_dims:
            f.write(struct.pack("<q", d))
        # 写入数据 (float32, 小端序)
        for x in ttl_stack:
            f.write(struct.pack("<f", x))
        for x in dp_stack:
            f.write(struct.pack("<f", x))
    
    print(f"  成功: 合并 {n} 个 voice(s) -> {bin_path} (sid 0..{n - 1})")


def main():
    # 获取项目根目录（脚本所在目录的上级）
    script_dir = Path(__file__).parent.parent
    
    # 生成 unicode_indexer.bin
    unicode_json = script_dir / "models" / "supertonic" / "onnx" / "unicode_indexer.json"
    unicode_bin = script_dir / "models" / "supertonic" / "onnx" / "unicode_indexer.bin"
    
    if unicode_json.exists():
        generate_unicode_indexer_bin(unicode_json, unicode_bin)
    else:
        print(f"警告: {unicode_json} 不存在，跳过")
    
    # 生成 voice.bin
    voice_styles_dir = script_dir / "models" / "supertonic" / "voice_styles"
    voice_bin = script_dir / "models" / "supertonic" / "voice.bin"
    
    if voice_styles_dir.exists():
        merge_voices_to_bin(voice_styles_dir, voice_bin)
    else:
        print(f"警告: {voice_styles_dir} 不存在，跳过")
    
    print("\n所有 .bin 文件生成完成！")
    print("请确保 pubspec.yaml 中已声明这些文件作为资产。")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        sys.exit(1)

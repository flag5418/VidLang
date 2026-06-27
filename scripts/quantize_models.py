#!/usr/bin/env python3
"""
ONNX 模型 INT8 量化脚本

用法:
    python3 scripts/quantize_models.py

量化内容:
    1. MarianMT encoder_model.onnx → encoder_model_int8.onnx
    2. MarianMT decoder_model.onnx → decoder_model_int8.onnx
    3. Supertonic text_encoder.onnx → text_encoder_int8.onnx
    4. Supertonic vector_estimator.onnx → vector_estimator_int8.onnx
    5. Supertonic vocoder.onnx → vocoder_int8.onnx
    6. Supertonic duration_predictor.onnx → duration_predictor_int8.onnx

量化方法: 动态量化（无需校准数据）
"""

import json
import os
import sys
from pathlib import Path

import onnx
from onnxruntime.quantization import quantize_static, QuantFormat, QuantType


def calibrate_marianmt_encoder(model_path):
    """为 MarianMT encoder 生成校准数据"""
    import numpy as np
    
    model = onnx.load(model_path)
    input_names = [inp.name for inp in model.graph.input]
    
    # 生成随机校准数据（实际使用时应该用真实文本的 token IDs）
    calibration_data = []
    num_samples = 100
    
    for _ in range(num_samples):
        seq_len = np.random.randint(10, 64)
        input_ids = np.random.randint(0, 1000, (1, seq_len)).astype(np.int64)
        attention_mask = np.ones((1, seq_len), dtype=np.int64)
        
        feed_dict = {}
        if 'input_ids' in input_names:
            feed_dict['input_ids'] = input_ids
        if 'attention_mask' in input_names:
            feed_dict['attention_mask'] = attention_mask
        
        calibration_data.append(feed_dict)
    
    return calibration_data


class MarianMTCalibrationDataReader:
    """MarianMT 校准数据读取器"""
    
    def __init__(self, model_path, num_samples=100):
        self.model = onnx.load(model_path)
        self.input_names = [inp.name for inp in self.model.graph.input]
        self.num_samples = num_samples
    
    def __iter__(self):
        for _ in range(self.num_samples):
            seq_len = np.random.randint(10, 64)
            input_ids = np.random.randint(0, 1000, (1, seq_len)).astype(np.int64)
            attention_mask = np.ones((1, seq_len), dtype=np.int64)
            
            feed_dict = {}
            if 'input_ids' in self.input_names:
                feed_dict['input_ids'] = input_ids
            if 'attention_mask' in self.input_names:
                feed_dict['attention_mask'] = attention_mask
            
            yield feed_dict


def quantize_model(model_path, output_path, calibration_data_reader=None, is_encoder_decoder=False):
    """量化单个 ONNX 模型"""
    if not os.path.exists(model_path):
        print(f"  ✗ 模型文件不存在: {model_path}")
        return False
    
    original_size = os.path.getsize(model_path) / (1024 * 1024)
    print(f"\n  量化: {Path(model_path).name}")
    print(f"    原始大小: {original_size:.1f} MB")
    
    try:
        if calibration_data_reader is not None:
            # 静态量化（需要校准数据）
            quantize_static(
                model_input=model_path,
                model_output=output_path,
                calibration_data_reader=calibration_data_reader,
                quant_format=QuantFormat.QDQ,
                activation_type=QuantType.QUInt8,
                weight_type=QuantType.QInt8,
                reduce_range=True,  # iOS 非 VNNI 架构
                per_channel=False,
            )
        else:
            # 动态量化（无需校准数据，适用于大多数场景）
            from onnxruntime.quantization import quantize_dynamic
            
            quantize_dynamic(
                model_input=model_path,
                model_output=output_path,
                weight_type=QuantType.QInt8,
                per_channel=False,
                reduce_range=True,
            )
        
        quantized_size = os.path.getsize(output_path) / (1024 * 1024)
        reduction = (1 - quantized_size / original_size) * 100
        
        print(f"    量化后大小: {quantized_size:.1f} MB")
        print(f"    体积减少: {reduction:.1f}%")
        
        if quantized_size > original_size * 1.1:
            print(f"    ⚠ 警告：量化后文件变大了！动态量化可能对某些模型无效。")
            print(f"    建议改用静态量化。")
            return None  # 返回 None 表示不确定
        
        return True
        
    except Exception as e:
        print(f"  ✗ 量化失败: {e}")
        return False


def main():
    script_dir = Path(__file__).parent.parent
    assets_dir = script_dir / "assets" / "models"
    quantized_dir = script_dir / "models_quantized"
    
    # 创建输出目录
    quantized_dir.mkdir(exist_ok=True)
    print(f"量化输出目录: {quantized_dir}\n")
    
    results = {}
    
    # ========== 1. MarianMT 模型 ==========
    print("=" * 60)
    print("1. MarianMT 翻译模型")
    print("=" * 60)
    
    marianmt_dir = assets_dir / "marianmt-onnx"
    
    encoder_path = str(marianmt_dir / "encoder_model.onnx")
    encoder_output = str(quantized_dir / "marianmt" / "encoder_model_int8.onnx")
    os.makedirs(os.path.dirname(encoder_output), exist_ok=True)
    results['marianmt_encoder'] = quantize_model(encoder_path, encoder_output)
    
    decoder_path = str(marianmt_dir / "decoder_model.onnx")
    decoder_output = str(quantized_dir / "marianmt" / "decoder_model_int8.onnx")
    os.makedirs(os.path.dirname(decoder_output), exist_ok=True)
    results['marianmt_decoder'] = quantize_model(decoder_path, decoder_output)
    
    # ========== 2. Supertonic TTS 模型 ==========
    print("\n" + "=" * 60)
    print("2. Supertonic TTS 模型")
    print("=" * 60)
    
    supertonic_dir = assets_dir / "supertonic" / "onnx"
    
    tts_models = [
        "text_encoder.onnx",
        "vector_estimator.onnx",
        "vocoder.onnx",
        "duration_predictor.onnx",
    ]
    
    for model_file in tts_models:
        model_path = str(supertonic_dir / model_file)
        output_path = str(quantized_dir / "supertonic" / model_file.replace(".onnx", "_int8.onnx"))
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        model_name = model_file.replace(".onnx", "")
        results[f"tts_{model_name}"] = quantize_model(model_path, output_path)
    
    # ========== 3. STT Whisper 模型 ==========
    print("\n" + "=" * 60)
    print("3. STT Whisper 模型")
    print("=" * 60)
    
    stt_dir = assets_dir / "stt"
    
    stt_models = [
        "encoder.onnx",
        "decoder.onnx",
    ]
    
    for model_file in stt_models:
        model_path = str(stt_dir / model_file)
        output_path = str(quantized_dir / "stt" / f"{model_file.replace('.onnx', '_int8.onnx')}")
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        model_name = model_file.replace(".onnx", "")
        results[f"stt_{model_name}"] = quantize_model(model_path, output_path)
    
    # ========== 总结 ==========
    print("\n" + "=" * 60)
    print("量化完成总结")
    print("=" * 60)
    
    success_count = sum(1 for v in results.values() if v is True)
    fail_count = sum(1 for v in results.values() if v is False)
    uncertain_count = sum(1 for v in results.values() if v is None)
    
    print(f"  ✓ 成功: {success_count}")
    print(f"  ✗ 失败: {fail_count}")
    print(f"  ⚠ 需检查: {uncertain_count}")
    print(f"\n量化后的模型位于: {quantized_dir}")
    print("\n下一步:")
    print("  1. 测试量化后的模型是否能正常工作")
    print("  2. 如果正常，替换 assets/models/ 中的原始模型")
    print("  3. 重新构建 App")
    
    # 打印详细的量化后大小
    print("\n量化后文件大小:")
    for name, model_path in [
        ("marianmt_encoder", encoder_output),
        ("marianmt_decoder", decoder_output),
    ] + [(f"tts_{m.replace('.onnx', '')}", str(quantized_dir / "supertonic" / m.replace(".onnx", "_int8.onnx"))) for m in tts_models] + [(f"stt_{m.replace('.onnx', '')}", str(quantized_dir / "stt" / m.replace(".onnx", "_int8.onnx"))) for m in stt_models]:
        if os.path.exists(model_path):
            size = os.path.getsize(model_path) / (1024 * 1024)
            print(f"  {name}: {size:.1f} MB")


if __name__ == "__main__":
    try:
        import numpy as np
    except ImportError:
        print("错误: 需要安装 numpy")
        print("运行: pip3 install numpy")
        sys.exit(1)
    
    try:
        main()
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)

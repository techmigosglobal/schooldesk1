import os
import sys
import json
import base64

def main():
    # Resolve project root (one level up from tool/ script location)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, ".."))
    
    # Path to input/output files
    env_file_path = os.path.join(project_root, "env.supabase.json")
    output_file_path = os.path.join(project_root, "ios", "Flutter", "DartDefines.xcconfig")
    
    if not os.path.exists(env_file_path):
        sys.stderr.write(f"Error: Environment file not found at: {env_file_path}\n")
        sys.exit(1)
        
    try:
        with open(env_file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        sys.stderr.write(f"Error: Failed to parse JSON from env.supabase.json: {e}\n")
        sys.exit(1)
    except Exception as e:
        sys.stderr.write(f"Error reading env.supabase.json: {e}\n")
        sys.exit(1)
        
    if not isinstance(data, dict):
        sys.stderr.write(f"Error: JSON root must be a JSON object, got {type(data).__name__}\n")
        sys.exit(1)
        
    encoded_entries = []
    
    for key, val in data.items():
        if isinstance(val, dict) or isinstance(val, list):
            # Key name is safe to print, but value is not
            sys.stderr.write(f"Error: Nested objects and arrays are not allowed. Key '{key}' has an invalid type.\n")
            sys.exit(1)
        elif isinstance(val, bool):
            str_val = "true" if val else "false"
        elif isinstance(val, (int, float)):
            str_val = str(val)
        elif val is None:
            str_val = ""
        elif isinstance(val, str):
            str_val = val
        else:
            sys.stderr.write(f"Error: Unsupported type for key '{key}': {type(val).__name__}\n")
            sys.exit(1)
            
        key_value_pair = f"{key}={str_val}"
        encoded_pair = base64.b64encode(key_value_pair.encode('utf-8')).decode('utf-8')
        encoded_entries.append(encoded_pair)
        
    # Join using commas, as required by Flutter's DART_DEFINES setting.
    # Start with $(inherited) to preserve any existing inherited Dart definitions.
    encoded_str = ",".join(encoded_entries)
    new_content = f"DART_DEFINES=$(inherited),{encoded_str}\n"
    
    # Patch the generated Swift Package Manager manifest to target iOS 15.0+ to resolve dependencies.
    patch_spm_package_manifest(project_root)

    # Avoid unnecessary rewrites when the output is unchanged
    existing_content = None
    if os.path.exists(output_file_path):
        try:
            with open(output_file_path, 'r', encoding='utf-8') as f:
                existing_content = f.read()
        except Exception:
            pass
            
    if existing_content == new_content:
        print("DartDefines.xcconfig is up to date (no changes).")
        return
        
    # Make sure output directory exists
    os.makedirs(os.path.dirname(output_file_path), exist_ok=True)
    
    try:
        with open(output_file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("Successfully generated ios/Flutter/DartDefines.xcconfig.")
    except Exception as e:
        sys.stderr.write(f"Error writing output file: {e}\n")
        sys.exit(1)

def patch_spm_package_manifest(project_root):
    package_swift_path = os.path.join(project_root, "ios", "Flutter", "ephemeral", "Packages", "FlutterGeneratedPluginSwiftPackage", "Package.swift")
    if os.path.exists(package_swift_path):
        try:
            with open(package_swift_path, 'r', encoding='utf-8') as f:
                content = f.read()
            if '.iOS("13.0")' in content:
                new_content = content.replace('.iOS("13.0")', '.iOS("15.0")')
                with open(package_swift_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print("Successfully patched FlutterGeneratedPluginSwiftPackage/Package.swift deployment target to iOS 15.0.")
        except Exception as e:
            sys.stderr.write(f"Warning: Failed to patch Package.swift: {e}\n")

if __name__ == "__main__":
    main()


#!/bin/bash
# Helper functions for Cloud Functions deployment

# Extract entry point from main.py
# Handles multiple patterns: def func(request), def func(request: Request), etc.
extract_entry_point() {
  local main_file="$1"
  # Try multiple patterns
  ENTRY_POINT=$(grep -Po '^def\s+\K\w+(?=\s*\([^)]*request[^)]*\):)' "$main_file" | head -n1)
  
  # If not found, try simpler pattern
  if [[ -z "$ENTRY_POINT" ]]; then
    ENTRY_POINT=$(grep -E '^def\s+\w+\s*\(' "$main_file" | head -n1 | grep -oP 'def\s+\K\w+')
  fi
  
  echo "$ENTRY_POINT"
}

# Detect required environment variables for a function
# Scans main.py for os.getenv() calls to determine what env vars are needed
get_function_env_vars() {
  local main_file="$1"
  local fn_dir="$2"
  local required_vars=""
  
  # Base DB variables (all functions need these)
  local base_vars="DB_HOST,DB_USER,DB_PASS,DB_NAME,DB_PORT,DB_SCHEMA"
  
  # Check for specific env vars in main.py
  if grep -q "os.getenv.*BASE_URL" "$main_file" 2>/dev/null; then
    required_vars="${required_vars}BASE_URL,"
  fi
  
  if grep -q "os.getenv.*SEND_EMAIL_URL" "$main_file" 2>/dev/null; then
    required_vars="${required_vars}SEND_EMAIL_URL,"
  fi
  
  if grep -q "os.getenv.*APP_URL" "$main_file" 2>/dev/null; then
    required_vars="${required_vars}APP_URL,"
  fi
  
  if grep -q "os.getenv.*EMAIL_TEMPLATE" "$main_file" 2>/dev/null; then
    required_vars="${required_vars}EMAIL_TEMPLATE,"
  fi
  
  if grep -q "os.getenv.*BUCKET_NAME" "$main_file" 2>/dev/null; then
    required_vars="${required_vars}BUCKET_NAME,"
  fi
  
  # Combine base vars with function-specific vars
  if [[ -n "$required_vars" ]]; then
    required_vars="${base_vars},${required_vars}"
  else
    required_vars="$base_vars"
  fi
  
  # Remove trailing comma
  required_vars=$(echo "$required_vars" | sed 's/,$//')
  
  echo "$required_vars"
}

# Build env vars string for a specific function
# Extracts only the required variables from the full env vars string
build_function_env_vars() {
  local required_vars="$1"
  local all_env_vars="$2"
  local environment="$3"
  local function_env_vars="ENV=${environment}"
  
  # Create a temporary file to parse env vars
  local temp_file=$(mktemp)
  echo "$all_env_vars" | tr ',' '\n' > "$temp_file"
  
  # Split required vars into array
  IFS=',' read -ra REQUIRED <<< "$required_vars"
  
  # Add required variables from all_env_vars
  for var in "${REQUIRED[@]}"; do
    var=$(echo "$var" | xargs) # trim whitespace
    if [[ -n "$var" ]]; then
      # Find the variable in all_env_vars (handle both KEY=value and KEY=value, formats)
      var_line=$(grep "^${var}=" "$temp_file" | head -n1)
      if [[ -n "$var_line" ]]; then
        # Extract the full KEY=value pair
        var_pair=$(echo "$var_line" | cut -d'=' -f1-)
        if [[ -n "$var_pair" ]]; then
          function_env_vars="${function_env_vars},${var_pair}"
        fi
      fi
    fi
  done
  
  rm -f "$temp_file"
  
  echo "$function_env_vars"
}

# Check if function uses bucket trigger
is_bucket_trigger() {
  local main_file="$1"
  local fn_dir="$2"
  
  # Check deployment comments for explicit --trigger-bucket
  if grep -q "--trigger-bucket" "$main_file" 2>/dev/null; then
    return 0
  fi
  
  # Check folder name patterns (for future bucket-triggered functions)
  if [[ "$fn_dir" == *"CSVtoDB"* ]] || \
     [[ "$fn_dir" == *"load"* ]] || \
     [[ "$fn_dir" == *"split"* ]]; then
    return 0
  fi
  
  # Explicitly exclude known HTTP-triggered functions that use storage
  if [[ "$fn_dir" == *"uploadCv"* ]] || \
     [[ "$fn_dir" == *"getMasterFile"* ]]; then
    return 1
  fi
  
  # Check for bucket event handler patterns
  if grep -q "def.*event\|def.*data.*bucket\|def.*file.*event" "$main_file" 2>/dev/null; then
    return 0
  fi
  
  return 1
}

# Build function name with environment prefix
build_function_name() {
  local fn_folder="$1"
  local entry_point="$2"
  local env_prefix="$3"
  
  # Check if folder name contains _v2 to identify v2 functions
  if [[ "$fn_folder" == *_v2 ]]; then
    # V2 function folder - ensure entry point has _v2 suffix
    if [[ "$entry_point" == *_v2 ]]; then
      # Entry point already has _v2
      FUNCTION_NAME="${env_prefix}${entry_point}"
    else
      # Entry point missing _v2: add it
      FUNCTION_NAME="${env_prefix}${entry_point}_v2"
    fi
  else
    # Legacy function
    FUNCTION_NAME="${env_prefix}${entry_point}"
  fi
  
  echo "$FUNCTION_NAME"
}

# Check if directory has changes
has_changes() {
  local fn_dir="$1"
  local branch="${2:-main}"
  local changed_files=""
  
  if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
    BASE_SHA=$(git merge-base "origin/$branch" HEAD 2>/dev/null || echo "")
    if [[ -n "$BASE_SHA" ]] && [[ "$BASE_SHA" != "$(git rev-parse HEAD)" ]]; then
      changed_files=$(git diff --name-only "$BASE_SHA" HEAD -- "$fn_dir" || echo "")
    fi
  fi
  
  if [[ -z "$changed_files" ]]; then
    # Check if files exist in current commit
    if git ls-tree -r --name-only HEAD -- "$fn_dir" | grep -q .; then
      return 0
    else
      return 1
    fi
  else
    return 0
  fi
}

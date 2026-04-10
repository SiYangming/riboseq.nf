#!/bin/bash

################################################################################
# Unified Riboseq Pipeline Management Script
# 
# This script consolidates all previous management scripts:
# - run_test.sh
# - run_pipeline.sh
# - diagnose.sh
# - view_logs.sh
#
# Usage: ./run.sh [COMMAND] [OPTIONS]
# Run './run.sh help' for detailed usage information
################################################################################

set -euo pipefail

#==============================================================================
# CONFIGURATION
#==============================================================================

# Pipeline configuration
PIPELINE_DIR="${PIPELINE_DIR:-./}"
CONFIG_FILE="${CONFIG_FILE:-conf/test_local.config}"
WORK_DIR="${WORK_DIR:-nextflow_work}"
LOG_FILE="${LOG_FILE:-.nextflow.log}"
OUT_FILE="${OUT_FILE:-nextflow.out}"
PID_FILE="${PID_FILE:-${OUT_FILE}.pid}"
RUNWAY="${RUNWAY:-docker}"
OUTDIR="${OUTDIR:-results_testdata}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
OFFLINE="${NXF_OFFLINE:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

# Print colored message
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Print section header
print_header() {
    echo
    print_color "$CYAN" "======================================================================"
    print_color "$CYAN" "$1"
    print_color "$CYAN" "======================================================================"
    echo
}

# Print success message
print_success() {
    print_color "$GREEN" "✓ $@"
}

# Print error message
print_error() {
    print_color "$RED" "✗ $@"
}

# Print warning message
print_warning() {
    print_color "$YELLOW" "⚠ $@"
}

# Print info message
print_info() {
    print_color "$BLUE" "ℹ $@"
}

# Check if pipeline is running
is_pipeline_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            local cmd
            cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
            if echo "$cmd" | grep -q 'nextflow run'; then
                return 0
            fi
        fi
        rm -f "$PID_FILE"
    fi
    return 1
}

# Get pipeline PID
get_pipeline_pid() {
    if [[ -f "$PID_FILE" ]]; then
        cat "$PID_FILE" 2>/dev/null || echo ""
    fi
}

#==============================================================================
# HELP AND VERSION
#==============================================================================

show_help() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                   Riboseq Pipeline Management Tool                           ║
║                          Unified run.sh Script                               ║
╚══════════════════════════════════════════════════════════════════════════════╝

USAGE:
    ./run.sh [COMMAND] [OPTIONS]

PIPELINE CONTROL COMMANDS:
    start               Start the pipeline
    stop                Stop the running pipeline
    restart             Restart the pipeline
    status              Show pipeline status
    clean               Clean work directory

LOG VIEWING COMMANDS:
    logs [N]            Show last N lines of log (default: 50)
    logs-full           Show full log with scrolling
    logs-follow         Follow log in real-time (recommended for monitoring)
    logs-error          Show only errors and warnings
    logs-search <term>  Search for term in logs
    logs-tail [N]       Show last N lines and follow

DIAGNOSTIC COMMANDS:
    diagnose            Run complete diagnostics (recommended first step!)
    check-files         Check input files exist
    check-config        Validate configuration file
    check-docker        Check Docker status
    check-disk          Check disk space

RESULTS COMMANDS:
    report              Show path to MultiQC report
    results             List result files
    summary             Show run summary

OTHER COMMANDS:
    config              Show current configuration
    version             Show version information
    help                Show this help message

EXAMPLES:
    # First time setup
    ./run.sh diagnose          # Check environment
    ./run.sh start             # Start pipeline
    ./run.sh logs-follow       # Monitor in real-time

    # Daily monitoring
    ./run.sh status            # Quick status check
    ./run.sh logs              # View recent logs
    ./run.sh logs-error        # Check for errors

    # Debugging
    ./run.sh logs-search ERROR # Find errors
    ./run.sh logs 200          # View more context
    ./run.sh diagnose          # Re-run diagnostics

    # After completion
    ./run.sh summary           # View run summary
    ./run.sh report            # Get report path
    ./run.sh clean             # Clean up work directory

TIPS:
    • Always run 'diagnose' before starting the pipeline
    • Use 'logs-follow' in a separate terminal for real-time monitoring
    • Run 'logs-error' periodically to check for issues
    • Use 'clean' after successful completion to free disk space

For documentation, see: run_sh/QUICK_START.md (EN) and run_sh/使用说明.md (中文)

EOF
}

show_version() {
    print_header "Version Information"
    echo "Script Version: 1.0.0"
    echo "Script Date: 2026-04-08"
    echo
    
    if command -v nextflow &> /dev/null; then
        echo "Nextflow Version:"
        nextflow -version 2>&1 | head -3
    else
        print_warning "Nextflow not found"
    fi
    echo
}

#==============================================================================
# CONFIGURATION DISPLAY
#==============================================================================

show_config() {
    print_header "Current Configuration"
    
    echo "Pipeline Settings:"
    echo "  Pipeline Directory: $PIPELINE_DIR"
    echo "  Config File: $CONFIG_FILE"
    echo "  Work Directory: $WORK_DIR"
    echo "  Log File: $LOG_FILE"
    echo "  Output File: $OUT_FILE"
    echo
    
    echo "File Status:"
    [[ -f "$CONFIG_FILE" ]] && print_success "Config file exists" || print_error "Config file not found"
    [[ -f "$LOG_FILE" ]] && print_success "Log file exists" || print_info "Log file not created yet"
    [[ -d "$WORK_DIR" ]] && print_success "Work directory exists" || print_info "Work directory not created yet"
    echo
}

#==============================================================================
# PIPELINE CONTROL
#==============================================================================

start_pipeline() {
    print_header "Starting Riboseq Pipeline"
    
    # Check if already running
    if is_pipeline_running; then
        print_error "Pipeline is already running (PID: $(get_pipeline_pid))"
        print_info "Use './run.sh status' to check status"
        print_info "Use './run.sh stop' to stop the running pipeline"
        return 1
    fi
    
    # Check config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        print_info "Please ensure the configuration file exists"
        return 1
    fi
    
    # Check pipeline directory
    if [[ ! -d "$PIPELINE_DIR" ]]; then
        print_error "Pipeline directory not found: $PIPELINE_DIR"
        print_info "Please clone the pipeline repository first"
        return 1
    fi
    
    print_info "Configuration: $CONFIG_FILE"
    print_info "Pipeline: $PIPELINE_DIR"
    print_info "Work directory: $WORK_DIR"
    echo
    
    # Start pipeline
    print_info "Starting pipeline in background..."
    nohup env NXF_OFFLINE="$OFFLINE" nextflow run "$PIPELINE_DIR" -c "$CONFIG_FILE" -w "$WORK_DIR" -profile "$RUNWAY" --outdir "$OUTDIR" -resume $EXTRA_ARGS > "$OUT_FILE" 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"
    
    sleep 2
    
    if kill -0 $pid 2>/dev/null; then
        print_success "Pipeline started successfully (PID: $pid)"
        echo
        print_info "Monitor the pipeline with:"
        print_color "$CYAN" "  ./run.sh logs-follow    # Real-time log monitoring"
        print_color "$CYAN" "  ./run.sh status         # Check status"
        print_color "$CYAN" "  ./run.sh logs-error     # Check for errors"
    else
        if grep -q "Workflow execution completed successfully" "$OUT_FILE" 2>/dev/null || grep -q "Workflow execution completed successfully" "$LOG_FILE" 2>/dev/null; then
            print_success "Pipeline completed successfully"
            rm -f "$PID_FILE"
        else
            print_error "Failed to start pipeline"
            print_info "Check the output file: $OUT_FILE"
            rm -f "$PID_FILE"
            return 1
        fi
    fi
}

stop_pipeline() {
    print_header "Stopping Pipeline"
    
    if ! is_pipeline_running; then
        print_warning "No pipeline is currently running"
        return 0
    fi
    
    local pid=$(get_pipeline_pid)
    print_info "Stopping pipeline (PID: $pid)..."
    
    # Try graceful shutdown first
    kill -TERM "$pid" 2>/dev/null || true
    
    # Wait for process to stop
    local count=0
    while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
        sleep 1
        ((count++))
        echo -n "."
    done
    echo
    
    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        print_warning "Graceful shutdown failed, forcing..."
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    if ! kill -0 "$pid" 2>/dev/null; then
        print_success "Pipeline stopped successfully"
        rm -f "$PID_FILE"
    else
        print_error "Failed to stop pipeline"
        return 1
    fi
}

restart_pipeline() {
    print_header "Restarting Pipeline"
    
    if is_pipeline_running; then
        stop_pipeline
        sleep 2
    fi
    
    start_pipeline
}

show_status() {
    print_header "Pipeline Status"
    
    if is_pipeline_running; then
        local pid=$(get_pipeline_pid)
        print_success "Pipeline is RUNNING"
        echo
        echo "Process Information:"
        echo "  PID: $pid"
        
        if command -v ps &> /dev/null; then
            echo "  Started: $(ps -p $pid -o lstart= 2>/dev/null || echo 'Unknown')"
            echo "  CPU: $(ps -p $pid -o %cpu= 2>/dev/null || echo 'Unknown')%"
            echo "  Memory: $(ps -p $pid -o %mem= 2>/dev/null || echo 'Unknown')%"
        fi
        
        echo
        echo "Recent Activity (last 5 lines):"
        if [[ -f "$LOG_FILE" ]]; then
            tail -5 "$LOG_FILE" | sed 's/^/  /'
        else
            print_warning "Log file not found"
        fi
    else
        print_warning "Pipeline is NOT running"
        
        if [[ -f "$LOG_FILE" ]]; then
            echo
            echo "Last log entry:"
            tail -1 "$LOG_FILE" | sed 's/^/  /'
        fi
    fi
    
    echo
}

clean_work_dir() {
    print_header "Cleaning Work Directory"
    
    if is_pipeline_running; then
        print_error "Cannot clean while pipeline is running"
        print_info "Stop the pipeline first with: ./run.sh stop"
        return 1
    fi
    
    if [[ ! -d "$WORK_DIR" ]]; then
        print_warning "Work directory does not exist: $WORK_DIR"
        return 0
    fi
    
    # Calculate size
    local size=$(du -sh "$WORK_DIR" 2>/dev/null | cut -f1)
    
    print_warning "This will delete the work directory: $WORK_DIR"
    print_info "Current size: $size"
    echo
    read -p "Are you sure? (yes/no): " -r
    echo
    
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Removing work directory..."
        rm -rf "$WORK_DIR"
        print_success "Work directory cleaned"
        print_info "Freed approximately: $size"
    else
        print_info "Cancelled"
    fi
}

#==============================================================================
# LOG VIEWING
#==============================================================================

view_logs() {
    local lines=${1:-50}
    
    if [[ ! -f "$LOG_FILE" ]]; then
        print_error "Log file not found: $LOG_FILE"
        print_info "The pipeline may not have been started yet"
        return 1
    fi
    
    print_header "Pipeline Logs (Last $lines lines)"
    tail -n "$lines" "$LOG_FILE"
}

view_logs_full() {
    if [[ ! -f "$LOG_FILE" ]]; then
        print_error "Log file not found: $LOG_FILE"
        return 1
    fi
    
    print_header "Full Pipeline Logs"
    print_info "Use arrow keys to scroll, 'q' to quit"
    echo
    sleep 1
    
    less -R "$LOG_FILE"
}

view_logs_follow() {
    if [[ ! -f "$LOG_FILE" ]]; then
        print_error "Log file not found: $LOG_FILE"
        print_info "Waiting for log file to be created..."
        
        # Wait for log file to appear
        local count=0
        while [[ ! -f "$LOG_FILE" ]] && [[ $count -lt 30 ]]; do
            sleep 1
            ((count++))
        done
        
        if [[ ! -f "$LOG_FILE" ]]; then
            print_error "Log file not created after 30 seconds"
            return 1
        fi
    fi
    
    print_header "Following Pipeline Logs (Real-time)"
    print_info "Press Ctrl+C to stop following"
    echo
    sleep 1
    
    # Follow with highlighting
    tail -f "$LOG_FILE" | grep --line-buffered -E \
        --color=always \
        'ERROR|WARN|Submitted|Completed|cached|COMPLETED|succeeded|failed|.*'
}

view_logs_error() {
    if [[ ! -f "$LOG_FILE" ]]; then
        print_error "Log file not found: $LOG_FILE"
        return 1
    fi
    
    print_header "Errors and Warnings"
    
    # Extract ERROR and WARN lines
    local errors=$(grep -i "ERROR" "$LOG_FILE" 2>/dev/null | tail -50)
    local warnings=$(grep -i "WARN" "$LOG_FILE" 2>/dev/null | tail -50)
    
    if [[ -n "$errors" ]]; then
        print_color "$RED" "━━━ ERRORS ━━━"
        echo "$errors"
        echo
    else
        print_success "No errors found"
    fi
    
    if [[ -n "$warnings" ]]; then
        print_color "$YELLOW" "━━━ WARNINGS ━━━"
        echo "$warnings"
        echo
    else
        print_success "No warnings found"
    fi
    
    if [[ -z "$errors" ]] && [[ -z "$warnings" ]]; then
        print_success "No errors or warnings found in logs!"
    fi
}

search_logs() {
    local term=$1
    
    if [[ -z "$term" ]]; then
        print_error "Please provide a search term"
        print_info "Usage: ./run.sh logs-search <term>"
        return 1
    fi
    
    if [[ ! -f "$LOG_FILE" ]]; then
        print_error "Log file not found: $LOG_FILE"
        return 1
    fi
    
    print_header "Searching for: $term"
    
    grep -i --color=always "$term" "$LOG_FILE" | tail -50
    
    local count=$(grep -i -c "$term" "$LOG_FILE")
    echo
    print_info "Found $count occurrences of '$term'"
}

#==============================================================================
# DIAGNOSTIC FUNCTIONS
#==============================================================================

run_diagnostics() {
    print_header "Running Complete Diagnostics"
    
    local errors=0
    local warnings=0
    
    # Check 1: Configuration file
    echo "1. Checking configuration file..."
    if [[ -f "$CONFIG_FILE" ]]; then
        print_success "Configuration file found: $CONFIG_FILE"
        
        # Check for rRNA databases with URLs
        if grep -q "http" "$CONFIG_FILE" 2>/dev/null; then
            print_warning "Configuration contains URLs (rRNA databases may not be downloaded)"
            print_info "Run: python3 bin/download_rrna_databases.py"
            ((warnings++))
        fi
    else
        print_error "Configuration file not found: $CONFIG_FILE"
        ((errors++))
    fi
    echo
    
    # Check 2: Sample sheet
    echo "2. Checking sample sheet..."
    local samplesheet=$(grep "input" "$CONFIG_FILE" 2>/dev/null | grep -oP '(?<=").*(?=")' || echo "")
    if [[ -n "$samplesheet" ]] && [[ -f "$samplesheet" ]]; then
        print_success "Sample sheet found: $samplesheet"
        local sample_count=$(tail -n +2 "$samplesheet" | wc -l)
        print_info "Number of samples: $sample_count"
    else
        print_error "Sample sheet not found or not specified"
        ((errors++))
    fi
    echo
    
    # Check 3: Reference genome
    echo "3. Checking reference genome..."
    local fasta=$(grep "fasta" "$CONFIG_FILE" 2>/dev/null | grep -oP '(?<=").*(?=")' | head -1 || echo "")
    local gtf=$(grep "gtf" "$CONFIG_FILE" 2>/dev/null | grep -oP '(?<=").*(?=")' | head -1 || echo "")
    
    if [[ -n "$fasta" ]] && [[ -f "$fasta" ]]; then
        print_success "Reference FASTA found: $fasta"
    else
        print_error "Reference FASTA not found: $fasta"
        ((errors++))
    fi
    
    if [[ -n "$gtf" ]] && [[ -f "$gtf" ]]; then
        print_success "Reference GTF found: $gtf"
    else
        print_error "Reference GTF not found: $gtf"
        ((errors++))
    fi
    echo
    
    # Check 4: Docker
    echo "4. Checking Docker..."
    if command -v docker &> /dev/null; then
        if docker ps &> /dev/null; then
            print_success "Docker is installed and running"
        else
            print_error "Docker is installed but not running"
            print_info "Start Docker: sudo systemctl start docker"
            ((errors++))
        fi
    else
        print_error "Docker not found"
        ((errors++))
    fi
    echo
    
    # Check 5: Nextflow
    echo "5. Checking Nextflow..."
    if command -v nextflow &> /dev/null; then
        local nf_version=$(nextflow -version 2>&1 | grep "version" | head -1)
        print_success "Nextflow installed: $nf_version"
    else
        print_error "Nextflow not found"
        ((errors++))
    fi
    echo
    
    # Check 6: Disk space
    echo "6. Checking disk space..."
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    local disk_avail=$(df -h . | tail -1 | awk '{print $4}')
    
    if [[ $disk_usage -lt 80 ]]; then
        print_success "Disk usage: ${disk_usage}% (${disk_avail} available)"
    elif [[ $disk_usage -lt 90 ]]; then
        print_warning "Disk usage: ${disk_usage}% (${disk_avail} available)"
        print_info "Consider cleaning old work directories"
        ((warnings++))
    else
        print_error "Disk usage: ${disk_usage}% (${disk_avail} available)"
        print_info "Low disk space! Clean work directories immediately"
        ((errors++))
    fi
    echo
    
    # Check 7: Pipeline directory
    echo "7. Checking pipeline directory..."
    if [[ -d "$PIPELINE_DIR" ]]; then
        print_success "Pipeline directory found: $PIPELINE_DIR"
    else
        print_error "Pipeline directory not found: $PIPELINE_DIR"
        print_info "Clone the repository first"
        ((errors++))
    fi
    echo
    
    # Check 8: Work directory
    echo "8. Checking work directory..."
    if [[ -d "$WORK_DIR" ]]; then
        local work_size=$(du -sh "$WORK_DIR" 2>/dev/null | cut -f1)
        print_info "Work directory exists: $WORK_DIR (size: $work_size)"
    else
        print_info "Work directory will be created on first run"
    fi
    echo
    
    # Summary
    print_header "Diagnostic Summary"
    
    if [[ $errors -eq 0 ]] && [[ $warnings -eq 0 ]]; then
        print_success "All checks passed! ✓"
        print_info "You can now start the pipeline with: ./run.sh start"
    elif [[ $errors -eq 0 ]]; then
        print_warning "$warnings warning(s) found"
        print_info "Pipeline should work, but review warnings above"
    else
        print_error "$errors error(s) and $warnings warning(s) found"
        print_info "Please fix errors before starting the pipeline"
        return 1
    fi
}

check_files() {
    print_header "Checking Input Files"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Check sample sheet
    local samplesheet=$(grep "input" "$CONFIG_FILE" 2>/dev/null | grep -oP '(?<=").*(?=")' || echo "")
    if [[ -n "$samplesheet" ]]; then
        if [[ -f "$samplesheet" ]]; then
            print_success "Sample sheet: $samplesheet"
            
            # Check individual sample files
            local missing=0
            while IFS=, read -r sample fastq_1 fastq_2 strandedness; do
                [[ "$sample" == "sample" ]] && continue  # Skip header
                
                if [[ ! -f "$fastq_1" ]]; then
                    print_error "Missing: $fastq_1"
                    ((missing++))
                fi
                
                if [[ -n "$fastq_2" ]] && [[ ! -f "$fastq_2" ]]; then
                    print_error "Missing: $fastq_2"
                    ((missing++))
                fi
            done < "$samplesheet"
            
            if [[ $missing -eq 0 ]]; then
                print_success "All sample files exist"
            else
                print_error "$missing file(s) missing"
                return 1
            fi
        else
            print_error "Sample sheet not found: $samplesheet"
            return 1
        fi
    else
        print_warning "Sample sheet path not found in config"
    fi
    
    echo
    
    # Check reference files
    local fasta=$(grep "fasta" "$CONFIG_FILE" 2>/dev/null | grep -oP '(?<=").*(?=")' | head -1 || echo "")
    local gtf=$(grep "gtf" "$CONFIG_FILE" 2>/dev/null | grep -oP '(?<=").*(?=")' | head -1 || echo "")
    
    if [[ -f "$fasta" ]]; then
        print_success "Reference FASTA: $fasta"
    else
        print_error "Reference FASTA not found: $fasta"
        return 1
    fi
    
    if [[ -f "$gtf" ]]; then
        print_success "Reference GTF: $gtf"
    else
        print_error "Reference GTF not found: $gtf"
        return 1
    fi
}

check_config_file() {
    print_header "Validating Configuration"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    print_success "Configuration file exists"
    echo
    
    # Check for required parameters
    echo "Required parameters:"
    local params=(
        "input"
        "fasta"
        "gtf"
        "outdir"
    )
    
    local missing=0
    for param in "${params[@]}"; do
        if grep -q "$param" "$CONFIG_FILE"; then
            local value=$(grep "$param" "$CONFIG_FILE" | head -1 | cut -d'=' -f2- | tr -d ' "')
            print_success "$param: $value"
        else
            print_error "Missing parameter: $param"
            ((missing++))
        fi
    done
    
    if [[ $missing -gt 0 ]]; then
        print_error "$missing required parameter(s) missing"
        return 1
    fi
    
    echo
    print_success "Configuration validation passed"
}

check_docker_status() {
    print_header "Checking Docker"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        print_info "Install Docker: https://docs.docker.com/get-docker/"
        return 1
    fi
    
    print_success "Docker is installed"
    
    local version=$(docker --version)
    print_info "Version: $version"
    echo
    
    if docker ps &> /dev/null; then
        print_success "Docker daemon is running"
        
        # Show Docker info
        echo
        echo "Docker containers:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | head -5
        
    else
        print_error "Docker daemon is not running"
        print_info "Start Docker:"
        print_info "  sudo systemctl start docker"
        print_info "Or add your user to docker group:"
        print_info "  sudo usermod -aG docker \$USER"
        return 1
    fi
}

check_disk_space() {
    print_header "Checking Disk Space"
    
    echo "Current directory: $(pwd)"
    df -h . | tail -1 | awk '{printf "  Total: %s\n  Used: %s (%s)\n  Available: %s\n", $2, $3, $5, $4}'
    echo
    
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [[ $disk_usage -lt 70 ]]; then
        print_success "Disk space is adequate"
    elif [[ $disk_usage -lt 85 ]]; then
        print_warning "Disk usage is moderate"
        print_info "Consider cleaning old files if usage increases"
    else
        print_error "Disk space is low!"
        print_info "Free up space before starting pipeline"
        print_info "Use './run.sh clean' to remove work directory"
        return 1
    fi
    
    # Show work directory size if exists
    if [[ -d "$WORK_DIR" ]]; then
        echo
        echo "Work directory size:"
        du -sh "$WORK_DIR" | awk '{printf "  %s\n", $1}'
    fi
}

#==============================================================================
# RESULTS FUNCTIONS
#==============================================================================

show_report() {
    print_header "MultiQC Report"
    
    # Try to find MultiQC report
    local report=$(find . -name "multiqc_report.html" 2>/dev/null | head -1)
    
    if [[ -n "$report" ]]; then
        print_success "Report found: $report"
        echo
        print_info "Open in browser:"
        print_color "$CYAN" "  firefox $report"
        print_color "$CYAN" "  google-chrome $report"
    else
        print_warning "MultiQC report not found"
        print_info "Report will be generated after pipeline completes"
    fi
}

show_results() {
    print_header "Result Files"
    
    # Find results directory
    local outdir=$(grep "outdir" "$CONFIG_FILE" 2>/dev/null | grep -oP '(?<=").*(?=")' || echo "results")
    
    if [[ -d "$outdir" ]]; then
        print_success "Results directory: $outdir"
        echo
        
        echo "Directory structure:"
        tree -L 2 "$outdir" 2>/dev/null || find "$outdir" -maxdepth 2 -type d | sed 's|[^/]*/|  |g'
        
        echo
        echo "Key result files:"
        find "$outdir" -type f \( -name "*.html" -o -name "*.pdf" -o -name "*results.csv" \) | head -20 | sed 's/^/  /'
    else
        print_warning "Results directory not found: $outdir"
        print_info "Results will appear here after pipeline completes"
    fi
}

show_summary() {
    print_header "Pipeline Summary"
    
    if [[ ! -f "$LOG_FILE" ]]; then
        print_warning "No log file found - pipeline hasn't run yet"
        return 0
    fi
    
    # Extract key information from log
    echo "Pipeline Information:"
    grep "Launching" "$LOG_FILE" 2>/dev/null | tail -1 | sed 's/^/  /'
    echo
    
    echo "Completed Processes:"
    local completed=$(grep -c "Completed" "$LOG_FILE" 2>/dev/null || echo "0")
    print_info "Total: $completed processes"
    grep "Completed" "$LOG_FILE" 2>/dev/null | tail -10 | sed 's/^/  /'
    echo
    
    # Check for completion
    if grep -q "Workflow execution completed successfully" "$LOG_FILE" 2>/dev/null; then
        print_success "Pipeline completed successfully!"
    elif grep -q "Error" "$LOG_FILE" 2>/dev/null; then
        print_error "Pipeline encountered errors"
        print_info "Check errors with: ./run.sh logs-error"
    elif is_pipeline_running; then
        print_info "Pipeline is still running"
    else
        print_warning "Pipeline status unclear"
    fi
}

#==============================================================================
# MAIN COMMAND DISPATCHER
#==============================================================================

main() {
    local command=${1:-help}
    shift || true
    
    case "$command" in
        # Pipeline control
        start)
            start_pipeline
            ;;
        stop)
            stop_pipeline
            ;;
        restart)
            restart_pipeline
            ;;
        status)
            show_status
            ;;
        clean)
            clean_work_dir
            ;;
            
        # Log viewing
        logs)
            view_logs "$@"
            ;;
        logs-full)
            view_logs_full
            ;;
        logs-follow)
            view_logs_follow
            ;;
        logs-error)
            view_logs_error
            ;;
        logs-search)
            search_logs "$@"
            ;;
        logs-tail)
            view_logs "${1:-50}"
            ;;
            
        # Diagnostics
        diagnose)
            run_diagnostics
            ;;
        check-files)
            check_files
            ;;
        check-config)
            check_config_file
            ;;
        check-docker)
            check_docker_status
            ;;
        check-disk)
            check_disk_space
            ;;
            
        # Results
        report)
            show_report
            ;;
        results)
            show_results
            ;;
        summary)
            show_summary
            ;;
            
        # Other
        config)
            show_config
            ;;
        version)
            show_version
            ;;
        help|--help|-h)
            show_help
            ;;
            
        *)
            print_error "Unknown command: $command"
            echo
            print_info "Run './run.sh help' for usage information"
            return 1
            ;;
    esac
}

#==============================================================================
# ENTRY POINT
#==============================================================================

# Run main function
main "$@"

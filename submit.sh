#!/bin/bash

set -e

# ============================================================
# submit.sh - Package xv6 syscall project for submission
# ============================================================

echo ""
echo "=========================================="
echo "  XV6 Syscall Project - Submission Tool"
echo "=========================================="
echo ""

# --- Collect student IDs ---
echo "Enter Student ID 1 (smallest):"
read -r id1
echo "Enter Student ID 2 (or leave blank if none):"
read -r id2
echo "Enter Student ID 3 (or leave blank if none):"
read -r id3

# Format the base filename: StudentID1_StudentID2_StudentID3
if [ -z "$id2" ]; then
    BASENAME="${id1}"
elif [ -z "$id3" ]; then
    BASENAME="${id1}_${id2}"
else
    BASENAME="${id1}_${id2}_${id3}"
fi

echo ""
echo "Packaging submission as: ${BASENAME}.zip"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="${SCRIPT_DIR}"
SUBMIT_DIR="${WORK_DIR}/_submit_tmp"
FRESH_XV6="${SUBMIT_DIR}/xv6-labs-2024"

# --- Cleanup any previous attempt ---
rm -rf "$SUBMIT_DIR"
mkdir -p "$SUBMIT_DIR"

# ============================================================
# Step 1: Clone a fresh, clean xv6 repository
# ============================================================
echo "[1/7] Cloning fresh xv6 repository..."
git clone --depth 10 -q git://g.csail.mit.edu/xv6-labs-2024 "$FRESH_XV6"

# ============================================================
# Step 2: Apply modified files from the working xv6 copy
# ============================================================
echo "[2/7] Applying modified kernel and user files..."

# These files were modified in-place by patch.sh / integrate.sh
MODIFIED_FILES=(
    Makefile
    kernel/defs.h
    kernel/kalloc.c
    kernel/proc.c
    kernel/proc.h
    kernel/syscall.c
    kernel/syscall.h
    kernel/sysproc.c
    user/user.h
    user/usertests.c
    user/usys.pl
)

for f in "${MODIFIED_FILES[@]}"; do
    cp "${WORK_DIR}/xv6/${f}" "${FRESH_XV6}/${f}"
done

# New kernel headers created by patch.sh
cp "${WORK_DIR}/xv6/kernel/ptree.h"   "${FRESH_XV6}/kernel/ptree.h"
cp "${WORK_DIR}/xv6/kernel/sysinfo.h" "${FRESH_XV6}/kernel/sysinfo.h"

# ============================================================
# Step 3: Copy user-space commands (resolve symlinks)
# ============================================================
echo "[3/7] Copying user-space commands..."

# Copy from commands/ directory (the canonical source)
for file in "${WORK_DIR}"/commands/*.c; do
    [ -e "$file" ] || continue
    filename=$(basename "$file")
    cp "$file" "${FRESH_XV6}/user/${filename}"
done

# ============================================================
# Step 4: Generate the git diff (patch file)
# ============================================================
echo "[4/7] Generating ${BASENAME}.patch..."

cd "$FRESH_XV6"

# Stage all new and modified files so git diff sees them
git add -N \
    Makefile \
    kernel/defs.h \
    kernel/kalloc.c \
    kernel/proc.c \
    kernel/proc.h \
    kernel/syscall.c \
    kernel/syscall.h \
    kernel/sysproc.c \
    kernel/ptree.h \
    kernel/sysinfo.h \
    user/user.h \
    user/usertests.c \
    user/usys.pl \
    user/*.c

git diff > "${WORK_DIR}/${BASENAME}.patch"

PATCH_LINES=$(wc -l < "${WORK_DIR}/${BASENAME}.patch")
echo "    Generated patch: ${PATCH_LINES} lines"

# ============================================================
# Step 5: Clean build artifacts
# ============================================================
echo "[5/7] Cleaning build artifacts..."
make clean > /dev/null 2>&1

# Remove symlinks that integrate.sh may have created in original xv6
# (not present in fresh clone, but just in case)
find user -type l -delete 2>/dev/null || true

cd "$WORK_DIR"

# ============================================================
# Step 6: Zip the cleaned source
# ============================================================
echo "[6/7] Zipping source code..."

# Zip from within submit dir for clean relative paths
cd "$SUBMIT_DIR"
zip -qr "${BASENAME}_Source.zip" "$(basename "$FRESH_XV6")/"
cd "$WORK_DIR"

# ============================================================
# Step 7: Package everything into final submission zip
# ============================================================
echo "[7/7] Creating final submission zip..."

FINAL_DIR="${SUBMIT_DIR}/submission"
mkdir -p "$FINAL_DIR"

# Move artifacts into submission folder
mv "${WORK_DIR}/${BASENAME}.patch" "${FINAL_DIR}/"
mv "${SUBMIT_DIR}/${BASENAME}_Source.zip" "${FINAL_DIR}/"

# Copy report PDF if it exists
REPORT_PDF=$(find "${WORK_DIR}/pdf" -name "*Report*.pdf" -o -name "*report*.pdf" 2>/dev/null | head -1)
if [ -n "$REPORT_PDF" ]; then
    cp "$REPORT_PDF" "${FINAL_DIR}/${BASENAME}_Report.pdf"
    echo "    Included report: ${BASENAME}_Report.pdf"
else
    echo "    WARNING: No *_Report.pdf found in pdf/ directory!"
    echo "    Place your report at: pdf/${BASENAME}_Report.pdf"
fi

# Create final zip
cd "${SUBMIT_DIR}"
zip -qr "${WORK_DIR}/${BASENAME}.zip" submission/

# ============================================================
# Cleanup temp directory
# ============================================================
rm -rf "$SUBMIT_DIR"

# ============================================================
# Done
# ============================================================
echo ""
echo "=========================================="
echo "  Submission ready!"
echo "=========================================="
echo ""
echo "  ${BASENAME}.zip"
echo ""
echo "  Contents:"
echo "    ${BASENAME}.patch         (git diff against clean xv6)"
echo "    ${BASENAME}_Source.zip    (source after make clean)"
if [ -n "$REPORT_PDF" ]; then
echo "    ${BASENAME}_Report.pdf    (lab report)"
fi
echo ""
echo "  Verify with: unzip -l ${BASENAME}.zip"
echo ""

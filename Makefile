# sorry non-windows users
# variable AMIGA_NDK must be defined to find amiga.lib and include files.

# update days manually here (must correspond to day#.asm files)
DAYS = day1
# if more utility modules are added, add them here
UTIL_SOURCES = util.asm

AS = vasmm68k_mot
LD = vlink

BIN_DIR = bin
OBJ_DIR = obj
INPUT_DIR = input

UTIL_OBJECTS = $(UTIL_SOURCES:%.asm=$(OBJ_DIR)/%.o)

BINARIES = $(addprefix $(BIN_DIR)/,$(DAYS))
SOURCES = $(addsuffix .asm,$(DAYS))
OBJECTS = $(SOURCES:%.asm=$(OBJ_DIR)/%.o)

ADF_VOLUME = aoc-2022
ADF = $(BIN_DIR)/$(ADF_VOLUME).adf

INCLUDE_DIR = $(AMIGA_NDK)/Include_I
LINK_LIB_DIR = $(AMIGA_NDK)/lib

LDFLAGS = -o $(BIN_DIR)/$* -bamigahunk -x -Bstatic -nostdlib -Z -mrel -L$(LINK_LIB_DIR) -lamiga
ASFLAGS = -o $(OBJ_DIR)/$*.o -chklabels -no-opt -m68000 -Fhunk -kick1hunks -nosym -I$(INCLUDE_DIR)


all: $(BINARIES)

packadf: $(ADF)

clean:
	del $(OBJ_DIR) /S /Q
	del $(BIN_DIR) /S /Q


$(BIN_DIR) $(OBJ_DIR): ; -mkdir $(subst /,\,$@)


$(OBJ_DIR)/%.o: %.asm | $(OBJ_DIR)
	$(AS) $< $(ASFLAGS)


$(BIN_DIR)/%: $(OBJ_DIR)/%.o $(UTIL_OBJECTS) | $(BIN_DIR)
	$(LD) $< $(UTIL_OBJECTS) $(LDFLAGS)


$(ADF): $(BINARIES)
	xdftool $(ADF) format $(ADF_VOLUME) + write $(BIN_DIR) bin + write $(INPUT_DIR) input + list


.SECONDARY: $(OBJECTS) $(UTIL_OBJECTS)
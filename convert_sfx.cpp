#include <algorithm>
#include <array>
#include <cstdio>
#include <cstring>
#include <string>
#include <sstream>
#include <vector>

constexpr int ntsc_notes[] = 
{
    0x07F1,0x077F,0x0713,0x06AD,0x064D,0x05F3,0x059D,0x054C,0x0500,0x04B8,0x0474,0x0434,
    0x03F8,0x03BF,0x0389,0x0356,0x0326,0x02F9,0x02CE,0x02A6,0x0280,0x025C,0x023A,0x021A,
    0x01FB,0x01DF,0x01C4,0x01AB,0x0193,0x017C,0x0167,0x0152,0x013F,0x012D,0x011C,0x010C,
    0x00FD,0x00EF,0x00E1,0x00D5,0x00C9,0x00BD,0x00B3,0x00A9,0x009F,0x0096,0x008E,0x0086,
    0x007E,0x0077,0x0070,0x006A,0x0064,0x005E,0x0059,0x0054,0x004F,0x004B,0x0046,0x0042,
    0x003F,0x003B,0x0038,0x0034,0x0031,0x002F,0x002C,0x0029,0x0027,0x0025,0x0023,0x0021,
    0x001F,0x001D,0x001B,0x001A,0x0018,0x0017,0x0015,0x0014,0x0013,0x0012,0x0011,0x0010,
    0x000F,0x000E,0x000D
};

struct bucket_t
{
    std::size_t size;
    std::string string;
};

struct track_t
{
    std::array<std::vector<int>, 4> notes;
    std::array<bool, 4> empty;
};

struct nsf_t
{
    std::vector<unsigned char> data;
    unsigned songs;
    unsigned load_addr;
    unsigned init_addr;
    unsigned play_addr;
};

char const* channel_name(int k)
{
    switch(k)
    {
    case 0: return "square1";
    case 1: return "square2";
    case 2: return "triangle";
    case 3: return "noise";
    default: return "error";
    }
}

unsigned char mem_rd(unsigned address);
void mem_wr(unsigned address, unsigned char data);

#include "cpu2a03.h"

std::array<unsigned char, 1 << 16> memory;
std::array<int, 32> apu_registers;
std::array<int, 32> prev_apu_registers;
std::array<int, 4> volume;
std::vector<track_t> tracks;
bool log;
bool effect_stop;

bool register_allowed(unsigned address)
{
    return (address == 0x4000 || address == 0x4002 || address == 0x4003
         || address == 0x4004 || address == 0x4006 || address == 0x4007
         || address == 0x4008 || address == 0x400A || address == 0x400B
         || address == 0x400C || address == 0x400E);
}

unsigned char mem_rd(unsigned address)
{
    return address < 0x2000 ? memory[address & 0x7FF] : memory[address];
}

void mem_wr(unsigned address, unsigned char data)
{
    // RAM writes:
    if(address < 0x2000)
    {
        memory[address & 0x7FF] = data;
        return;
    } 
    
    // Expansion memory.
    if(address >= 0x5C00 && address < 0x8000)
    {
        memory[address] = data;
        return;
    } 

    // APU registers:
    if(log && address < 0x4018)
    {
        if((address == 0x4001 || address == 0x4005) && (data & 0x80))
            throw std::runtime_error("sweep effects are not supported.\n");

        if(address >= 0x4010 && address <= 0x4013)
        {
            throw std::runtime_error("DMC is not supported.\n");
        }

        if(register_allowed(address) && apu_registers[address-0x4000] != data)
        {
            switch(address)
            {
            case 0x4000: volume[0] = data & 0x0F; break;
            case 0x4004: volume[1] = data & 0x0F; break;
            case 0x4008: volume[2] = data & 0x7F; break;
            case 0x400C: volume[3] = data & 0x0F; break;
            }

            apu_registers[address - 0x4000] = data;
        }

        // Catch the C00 effect.
        if(address == 0x4015 && data == 0)
            effect_stop = true;
    }
}

void convert_effect(std::vector<bucket_t>& buckets, 
                    std::ostream& os, std::ostream& ns,
                    nsf_t const& nsf, unsigned song, unsigned mode)
{
    memory.fill(0);
    std::memcpy(&memory[nsf.load_addr], &nsf.data[128], nsf.data.size()-128);

    apu_registers.fill(-1);
    apu_registers[0x00] = 0x30;
    apu_registers[0x04] = 0x30;
    apu_registers[0x08] = 0x30;
    apu_registers[0x0C] = 0x30;

    volume.fill(0);

    // Init nsf code.
    cpu_reset();
    CPU.A = song;
    CPU.X = mode;
    CPU.PC.hl = nsf.init_addr;
    log = false;
    for(unsigned i = 0; i < 2000; ++i) 
        cpu_tick(); // 2000 is enough for FT init
    cpu_reset();

    // Init nsf code.
    cpu_reset();
    CPU.A = song;
    CPU.X = mode;
    CPU.PC.hl = nsf.init_addr;
    log = false;
    for(unsigned i = 0; i < 2000; ++i) 
        cpu_tick(); // 2000 is enough for FT init
    cpu_reset();

    std::vector<std::array<int, 32>> apu_register_log;
    std::vector<std::array<int, 4>> volume_log;

    log = true;

    for(effect_stop = false; !effect_stop;)
    {
        CPU.PC.hl = nsf.play_addr;
        CPU.jam = false;
        CPU.S = 0xFF;

        for(unsigned i = 0; i < 30000/4 && !effect_stop; ++i)
            cpu_tick();

        apu_register_log.push_back(apu_registers);
        volume_log.push_back(volume);
    }

    // Volume & Duty
    for(unsigned k = 0; k < 4; ++k)
    {
        if(tracks[song].empty[k])
            continue;

        bucket_t bucket = {};
        std::stringstream ss;

        char const* chan = channel_name(k);

        ss << chan << "_sfx_" << song << "_vol_duty_pattern:\n";
        for(unsigned i = 0; i < apu_register_log.size(); ++i)
        {
            unsigned vol_duty = apu_register_log[i][0x00+k*4] | 0b110000;
            if(k == 2)
            {
                if(vol_duty & 0b1111)
                    vol_duty |= 0b1111;
            }
            ss << "    .byt " << vol_duty << '\n';
            bucket.size += 1;
        }

        bucket.string = ss.str();
        buckets.push_back(std::move(bucket));
    }

    // Pitch
    for(unsigned k = 0; k < 3; ++k)
    {
        if(tracks[song].empty[k])
            continue;

        bucket_t bucket = {};
        std::stringstream ss;
        char const* chan = channel_name(k);

        int pitch_bend = 0;
        ss << chan << "_sfx_" << song << "_pitch_pattern:\n";
        for(unsigned i = 0; i < apu_register_log.size(); ++i)
        {
            int note = tracks[song].notes[k][i];
            unsigned pitch = apu_register_log[i][0x02 + k*4];
            pitch |= (apu_register_log[i][0x03 + k*4] & 0b111) << 8;
            int diff = pitch - ntsc_notes[note] - pitch_bend;
            pitch_bend += diff;
            ss << ".byt .lobyte(" << diff << ")\n";
            bucket.size += 1;
        }

        bucket.string = ss.str();
        buckets.push_back(std::move(bucket));
    }

    // Arpeggio
    for(unsigned k = 0; k < 3; ++k)
    {
        if(tracks[song].empty[k])
            continue;

        bucket_t bucket = {};
        std::stringstream ss;
        char const* chan = channel_name(k);

        ss << chan << "_sfx_" << song << "_arpeggio_pattern:\n";
        for(unsigned i = 0; i < apu_register_log.size(); ++i)
        {
            int change = tracks[song].notes[k][i];
            change -= tracks[song].notes[k].front();
            change *= -2;
            ss << ".byt .lobyte(" << change << ")\n";
            bucket.size += 1;
        }

        bucket.string = ss.str();
        buckets.push_back(std::move(bucket));
    }

    // Subroutines
    for(unsigned k = 0; k < 4; ++k)
    {
        if(tracks[song].empty[k])
            continue;

        bucket_t bucket = {};
        std::stringstream ss;
        char const* chan = channel_name(k);

        ss << chan << "_sfx_" << song << "_vol_duty:\n";
        ss << "    jsr " << chan << "_sfx_call_return\n";
        ss << "    cpy #" << apu_register_log.size() << '\n';
        ss << "    bcc :+\n";
        ss << "    jmp end_" << chan << "_sfx\n";
        ss << ":   lda "<< chan <<"_sfx_"<< song <<"_vol_duty_pattern, y\n";
        ss << "    jmp " << chan << "_vol_duty_return\n";

        bucket.size = 3+2+2+3+3+3;
        bucket.string = ss.str();
        buckets.push_back(std::move(bucket));
    }

    for(unsigned k = 0; k < 3; ++k)
    {
        if(tracks[song].empty[k])
            continue;

        char const* chan = channel_name(k);

        os << chan << "_sfx_" << song << "_pitch:\n";
        os << "    jsr " << chan << "_sfx_" << song << "_vol_duty\n";
        os << "    nop\n";
        os << "    nop\n";
        os << "    sec\n";
        os << "    lda " << chan << "_sfx_" << song << "_pitch_pattern, x\n";
        os << "    jmp " << chan << "_pitch_return\n";
    }

    for(unsigned k = 0; k < 3; ++k)
    {
        if(tracks[song].empty[k])
            continue;

        char const* chan = channel_name(k);

        ns << ".global " << chan << "_sfx_" << song << "\n";

        os << chan << "_sfx_" << song << ":\n";
        os << "    tsx\n";
        os << "    stx sfx_stack_temp\n";
        os << "    lax " << chan << "_stack\n";
        os << "    axs #.lobyte(-6)\n";
        os << "    txs\n";
        os << "    ldx #0\n";
        os << "    stx " << chan << "_stack_next\n";
        if(k == 0 || k == 1)
        {
            os << "    dex\n";
            os << "    stx " << chan << "_pitch_hi\n";
        }
        os << "    lda #" << tracks[song].notes[k].front()*2 << '\n';
        os << "    sta " << chan << "_note\n";
        os << chan << "_sfx_" << song << "_arpeggio:\n";
        os << "    jsr " << chan << "_sfx_" << song << "_pitch\n";
        os << "    sbc "<<chan<<"_sfx_"<<song<<"_arpeggio_pattern, x\n";
        os << "    jmp " << chan << "_arpeggio_sfx_return\n";
    }

    if(!tracks[song].empty[3])
    {
        bucket_t bucket = {};
        std::stringstream ss;

        ns << ".global noise_sfx_" << song << "\n";

        os << "noise_sfx_" << song << ":\n";
        os << "    tsx\n";
        os << "    stx sfx_stack_temp\n";
        os << "    lax noise_stack\n";
        os << "    sta noise_stack_next\n";
        os << "    axs #.lobyte(-4)\n";
        os << "    txs\n";
        os << "    stx sfx_noise_play\n";
        os << "    lda #" << tracks[song].notes[3].front() << '\n';
        os << "    sta noise_note\n";
        os << "noise_sfx_" << song << "_arpeggio:\n";
        os << "    jsr noise_sfx_" << song << "_vol_duty\n";
        for(unsigned i = 0; i < apu_register_log.size(); ++i)
        {
            int change = tracks[song].notes[3][i];
            change -= tracks[song].notes[3].front();

            os << "    axs #.lobyte(" << -change << ")\n";
            os << "    jsr noise_arpeggio_return\n";
        }
    }
}

char const* parse_line(
    char const* const ptr, char const* const end, 
    std::vector<std::string>& words)
{
    words.clear();
    for(char const* last = ptr; last != end;)
    {
        while(last != end && std::isspace(*last))
            if(*(last++) == '\n')
                return last;
        char const* first = last;
        while(last != end && *last != ' ' && *last != '\n')
            ++last;
        words.emplace_back(first, last);
    }
    return end;
}

int parse_hexc(char const c)
{
    switch(c)
    {
    case '0': return 0x0;
    case '1': return 0x1;
    case '2': return 0x2;
    case '3': return 0x3;
    case '4': return 0x4;
    case '5': return 0x5;
    case '6': return 0x6;
    case '7': return 0x7;
    case '8': return 0x8;
    case '9': return 0x9;
    case 'A': return 0xA;
    case 'B': return 0xB;
    case 'C': return 0xC;
    case 'D': return 0xD;
    case 'E': return 0xE;
    case 'F': return 0xF;
    default: return -1;
    }
}

int parse_hex(std::string const& str)
{
    int d1 = parse_hexc(str[0]);
    int d2 = parse_hexc(str[1]);
    if(d1 < 0 || d2 < 0)
        return -1;
    return (d1 * 16) | d2;
}

int parse_note(std::string const& str)
{
    if(str == "...")
        return -1;
    if(str == "---")
        return -2;
    if(str == "===")
        return -2;

    if(str[2] == '#')
    {
        int r = parse_hexc(str[0]);
        if(r < 0)
            return -1;
        return r ^ 0b1111;
    }

    int note = -1;

    switch(str[0])
    {
    case 'C': note = 0; break;
    case 'D': note = 2; break;
    case 'E': note = 4; break;
    case 'F': note = 5; break;
    case 'G': note = 7; break;
    case 'A': note = 9; break;
    case 'B': note = 11; break;
    default: throw std::runtime_error("bad note");
    }

    switch(str[1])
    {
    case '#':
    case '+': ++note; break;
    case 'b':
    case 'f': --note; break;
    }

    note += 12 * (str[2] - '0');

    return note - 9;
}

bool fill_blank_notes(std::vector<int>& notes)
{
    if(notes.empty())
        return true;

    for(unsigned i = 0; i < notes.size(); ++i)
    {
        if(notes[i] >= 0)
        {
            notes.front() = notes[i];
            goto foundNote;
        }
    }
    return true;
foundNote:
    int prev = notes.front();
    for(unsigned i = 0; i < notes.size(); ++i)
    {
        if(notes[i] < 0)
            notes[i] = prev;
        else
            prev = notes[i];
    }
    return false;
}

int main(int argc, char** argv)
{
    if(argc != 5)
    {
        std::fprintf(stderr, "usage: %s [txt] [nsf] [out-data] [out-defs]\n", 
                     argv[0]);
        return 1;
    }

    FILE* fp = std::fopen(argv[1], "r");
    if(!fp)
    {
        std::fprintf(stderr, "can't open %s", argv[1]);
        return 1;
    }

    std::fseek(fp, 0, SEEK_END);
    std::size_t filesize = std::ftell(fp);
    std::fseek(fp, 0, SEEK_SET);

    std::vector<char> buffer(filesize);

    if(std::fread(buffer.data(), filesize, 1, fp) != 1)
    {
        std::fprintf(stderr, "can't read %s", argv[0]);
        return 1;
    }

    std::fclose(fp);
    fp == nullptr;

    char const* ptr = buffer.data();
    char const* end = buffer.data() + buffer.size();
    std::vector<std::string> words;
    track_t* active_track = nullptr;
    while(ptr != end)
    {
        ptr = parse_line(ptr, end, words);
        if(words.empty())
            continue;

        if(words[0] == "TRACK")
        {
            track_t track;
            tracks.push_back(track);
            active_track = &tracks.back();
        }
        else if(words[0] == "ROW")                            
        {
            auto it = words.begin();
            for(std::vector<int>& n : active_track->notes)
            {
                it = std::find(it, words.end(), ":");
                ++it;
                n.push_back(parse_note(*it));
            }
        }
    }

    for(track_t& t : tracks)
        for(unsigned i = 0; i < 4; ++i)
            t.empty[i] = fill_blank_notes(t.notes[i]);

    fp = std::fopen(argv[2], "r");
    if(!fp)
    {
        std::fprintf(stderr, "can't open %s", argv[2]);
        return 1;
    }

    std::fseek(fp, 0, SEEK_END);
    std::size_t const size = std::ftell(fp);
    std::fseek(fp, 0, SEEK_SET);

    nsf_t nsf = {};
    nsf.data.resize(size);

    std::fread(nsf.data.data(), size, 1, fp);
    std::fclose(fp);
    fp == nullptr;

    nsf.songs = nsf.data[0x06];
    nsf.load_addr = nsf.data[0x08] + (nsf.data[0x09] << 8);
    nsf.init_addr = nsf.data[0x0A] + (nsf.data[0x0B] << 8);
    nsf.play_addr = nsf.data[0x0C] + (nsf.data[0x0D] << 8);

    for(unsigned i = 0x70; i < 0x78; ++i)
    {
        if(nsf.data[i])
        {
            std::fprintf(stderr, "error: bankswitching is not supported\n");
            return 1;
        }
    }

    if(nsf.data[0x7B])
    {
        std::fprintf(stderr, "error: expansion chips are not supported\n");
        return 1;
    }

    fp = std::fopen(argv[3], "w");
    if(!fp)
    {
        std::fprintf(stderr, "can't open %s", argv[3]);
        return 1;
    }

    std::stringstream os;
    std::stringstream ns;
    std::vector<bucket_t> buckets;
    for(int i = 0; i < nsf.songs; ++i)
        convert_effect(buckets, os, ns, nsf, i, 0);

    std::sort(
        buckets.begin(), buckets.end(),
        [](bucket_t const& a, bucket_t const& b) { return a.size > b.size; });

    std::vector<bucket_t> allocated;

    for(bucket_t const& bucket : buckets)
    {
        if(bucket.size <= 0)
            throw std::runtime_error("bad size");
        for(bucket_t& a : allocated)
        {
            if(bucket.size + a.size <= 256)
            {
                a.size += bucket.size;
                a.string += bucket.string;
                goto inserted;
            }
        }
        allocated.push_back(bucket);
    inserted:;
    }

    for(bucket_t const& bucket : allocated)
    {
        std::fprintf(fp, "; size = %i\n.align 256\n%s", 
                     bucket.size, bucket.string.c_str());
    }
    
    std::fprintf(fp, "\n%s\n", os.str().c_str());

    std::fclose(fp);

    fp = std::fopen(argv[4], "w");
    if(!fp)
    {
        std::fprintf(stderr, "can't open %s", argv[4]);
        return 1;
    }
    std::fprintf(fp, "%s\n", ns.str().c_str());

    std::fclose(fp);
}

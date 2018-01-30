#include <iostream>
#include <algorithm>
#include <array>
#include <cstdio>
#include <cctype>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <vector>

struct bucket_t
{
    std::size_t size;
    std::string string;
};

struct macro_t
{
    //int type;
    //int index;
    int loop;
    //int release;
    //int setting;
    std::vector<int> sequence;

    static constexpr int volume = 0;
    static constexpr int arpeggio = 1;
    static constexpr int pitch = 2;
    static constexpr int hi_pitch = 3;
    static constexpr int duty = 4;
};

constexpr int macro_t::volume;
constexpr int macro_t::arpeggio;
constexpr int macro_t::pitch;
constexpr int macro_t::hi_pitch;
constexpr int macro_t::duty;

bool operator==(macro_t const& a, macro_t const& b)
{
    return (a.loop == b.loop 
            && a.sequence.size() == b.sequence.size()
            && std::equal(a.sequence.begin(), a.sequence.end(), 
                          b.sequence.begin()));
}

bool operator<(macro_t const& a, macro_t const& b)
{
    if(a.loop != b.loop)
        return a.loop < b.loop;
    return std::lexicographical_compare(
        a.sequence.begin(), a.sequence.end(),
        b.sequence.begin(), b.sequence.end());
}

struct instrument_t
{
    int seq_vol;
    int seq_arp;
    int seq_pit;
    int seq_hpi;
    int seq_dut;

    int pseq_vol_duty;
    int pseq_arp;
    int pseq_pit;
};

struct channel_data_t
{
    int note;
    int instrument;
};

bool operator==(channel_data_t a, channel_data_t b)
    { return a.note == b.note && a.instrument == b.instrument; }
bool operator<(channel_data_t a, channel_data_t b)
    { return std::tie(a.note, a.instrument) < std::tie(b.note, b.instrument); }

struct row_t
{
    int number;
    std::array<channel_data_t, 4> chan;
    std::array<bool, 4> d00;
    channel_data_t dpcm;
};

struct track_t
{
    int pattern_length;
    int speed;
    int tempo;
    std::array<int, 5> columns;
    std::vector<std::array<int, 5>> order;
    std::vector<std::vector<row_t>> patterns;
};

void fprint_byte_data(FILE* fp, int i, unsigned char data)
{
    if(i == 0)
        std::fprintf(fp,".byt ");
    else if(i % 16 == 0) 
        std::fprintf(fp,"\n.byt ");
    else 
        std::fprintf(fp, ",");
    std::fprintf(fp, "$%02X", data);
}

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

    return (note - 9) * 2;
}


macro_t combine_vol_duty(macro_t volume, macro_t duty)
{
    if(volume.loop < 0 || duty.loop < 0)
        throw std::runtime_error("can't combine non-looping macros");
    if(volume.loop >= volume.sequence.size()
       || duty.loop >= duty.sequence.size())
    {
        throw std::runtime_error("bad loop value");
    }

    std::size_t const max_size 
        = std::max(volume.sequence.size(), duty.sequence.size());

    std::size_t const volume_loop_size = volume.sequence.size() - volume.loop;
    std::size_t const duty_loop_size = duty.sequence.size() - duty.loop;

    std::size_t const max_loop = std::max(volume.loop, duty.loop);
    std::size_t const max_loop_size 
        = std::max(volume_loop_size, duty_loop_size);

    if(duty_loop_size % volume_loop_size != 0 
       && volume_loop_size % duty_loop_size != 0)
    {
        std::fprintf(stderr, "duty & vol loops not multiples\n");
    }

    macro_t combined = {};
    //combined.type = macro_t::vol_duty;

    for(std::size_t i = 0; i < max_loop + max_loop_size; ++i)
    {
        unsigned v = 0b00110000;

        std::size_t j = i;
        while(j >= volume.sequence.size())
            j -= (volume.sequence.size() - volume.loop);
        v |= volume.sequence[j];

        std::size_t k = i;
        while(k >= duty.sequence.size())
            k -= (duty.sequence.size() - duty.loop);
        v |= duty.sequence[k] << 6;

        combined.sequence.push_back(v);
        combined.loop = max_loop;
    }

    return combined;
}

unsigned char pattern_mask(std::array<channel_data_t, 8> pattern)
{
    unsigned char mask = 0;
    for(int j = 0; j < 8; ++j)
    {
        if(pattern[j].note >= 0)
            mask |= 1 << j;
    }
    return mask;
}

int main(int argc, char** argv)
{
    if(argc != 3)
    {
        std::fprintf(stderr, "usage: %s [infile] [outfile]", argv[0]);
        return 1;
    }

    FILE* fp = std::fopen(argv[1], "rb");
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
        std::fprintf(stderr, "can't read %s", argv[1]);
        return 1;
    }

    std::fclose(fp);

    char const* ptr = buffer.data();
    char const* end = buffer.data() + buffer.size();
    std::vector<std::string> words;
    std::map<std::pair<int, int>, macro_t> macros;
    std::map<int, instrument_t> instruments;
    std::vector<track_t> tracks;
    track_t* active_track = nullptr;
    std::vector<row_t>* active_pattern = nullptr;
    while(ptr != end)
    {
        ptr = parse_line(ptr, end, words);
        if(words.empty())
            continue;

        if(words[0] == "MACRO")
        {
            macro_t macro = {};
            int type    = std::atoi(words[1].c_str());
            int index   = std::atoi(words[2].c_str());
            macro.loop  = std::atoi(words[3].c_str());
            int release = std::atoi(words[4].c_str());
            int setting = std::atoi(words[5].c_str());
            for(int i = 7; i < words.size(); ++i)
                macro.sequence.push_back(std::atoi(words[i].c_str()));

            // Force macro to loop.
            if(macro.loop < 0 || macro.loop >= macro.sequence.size())
            {
                if(type == macro_t::pitch && macro.sequence.size() 
                   && macro.sequence.back() != 0)
                {
                    macro.sequence.push_back(0);
                }
                macro.loop = macro.sequence.size() - 1;
            }

            macros[std::make_pair(type, index)] = macro;
        }
        else if(words[0] == "INST2A03")
        {
            instrument_t instrument = {};
            instrument.seq_vol = std::atoi(words[2].c_str());
            instrument.seq_arp = std::atoi(words[3].c_str());
            instrument.seq_pit = std::atoi(words[4].c_str());
            instrument.seq_hpi = std::atoi(words[5].c_str());
            instrument.seq_dut = std::atoi(words[6].c_str());
            instrument.seq_dut = std::atoi(words[6].c_str());
            instruments.emplace(std::atoi(words[1].c_str()), instrument);
        }
        else if(words[0] == "TRACK")
        {
            track_t track;
            track.pattern_length = std::atoi(words[1].c_str());
            track.speed = std::atoi(words[2].c_str());
            track.tempo = std::atoi(words[3].c_str());
            tracks.push_back(track);
            active_track = &tracks.back();
        }
        else if(words[0] == "COLUMNS")
        {
            for(int i = 0; i < 5; ++i)
                active_track->columns[i] = std::atoi(words[i+2].c_str());
        }
        else if(words[0] == "ORDER")
        {
            active_track->order.push_back({});
            for(int i = 0; i < 5; ++i)
                active_track->order.back()[i] = parse_hex(words[i+3]);
        }
        else if(words[0] == "PATTERN")
        {
            active_track->patterns.push_back({});
            active_pattern = &active_track->patterns.back();
        }
        else if(active_pattern && words[0] == "ROW")                            
        {
            row_t row = {};

            row.number = parse_hex(words[1]);

            row.chan[0].note = parse_note(words[3]);
            row.chan[0].instrument = parse_hex(words[4]);

            row.chan[1].note = parse_note(words[8]);
            row.chan[1].instrument = parse_hex(words[9]);

            row.chan[2].note = parse_note(words[13]);
            row.chan[2].instrument = parse_hex(words[14]);

            row.chan[3].note = parse_note(words[18]);
            row.chan[3].instrument = parse_hex(words[19]);

            for(unsigned i = 0; i < 4; ++i)
                row.d00[i] = words[6+5*i] == "D00";

            active_pattern->push_back(row);

        }
    }

    // Add blank macros.
    {
        macro_t macro = {};
        macro.loop = 0;
        macro.sequence.push_back(0);
        macros[std::make_pair(macro_t::pitch, -1)] = macro;
        macros[std::make_pair(macro_t::arpeggio, -1)] = macro;
        macros[std::make_pair(macro_t::duty, -1)] = macro;
        macros[std::make_pair(macro_t::volume, -10)] = macro;
        macro.sequence[0] = 15;
        macros[std::make_pair(macro_t::volume, -1)] = macro;
    }

    // Add blank instruments
    {
        instrument_t instrument = {};
        instrument.seq_vol = -10;
        instrument.seq_arp = -1;
        instrument.seq_pit = -1;
        instrument.seq_hpi = -1;
        instrument.seq_dut = -1;
        instrument.pseq_vol_duty = -1;
        instrument.pseq_arp = -1;
        instrument.pseq_pit = -1;
        instruments.emplace(-1, instrument);
    }

    fp = std::fopen(argv[2], "w");
    if(!fp)
    {
        std::fprintf(stderr, "can't open %s", argv[2]);
        return 1;
    }

    std::vector<bucket_t> buckets;
    std::string arpeggio_string;

    std::array<std::map<int, int>, 4> penguin_instrument_map;
    std::array<std::vector<int>, 4> penguin_instrument_vector;

    std::map<std::array<channel_data_t, 8>, int> penguin_pattern_map;
    std::vector<std::array<channel_data_t, 8>> penguin_pattern_vector;

    for(int k = 0; k < 4; ++k)
    {
        penguin_instrument_map[k][-1] = 0;
        penguin_instrument_vector[k].push_back(-1);
    }

    std::fprintf(fp, ".align 256\n");
    for(std::size_t t = 0; t < tracks.size(); ++t)
    {
        track_t const& track = tracks[t];
        std::vector<int> penguin_channels[4];

        for(auto const& pattern_array : track.order)
        {
            std::size_t ps = -1;
            for(std::size_t k = 0; k < 4; ++k)
            {
                auto const& pv = track.patterns.at(pattern_array[k]);
                unsigned size = 0;
                for(row_t const& row : pv)
                {
                    ++size;
                    if(row.d00[k])
                        break;
                }
                if(size % 8 != 0)
                    throw std::runtime_error("pattern size not multiple of 8");
                if(size / 8 < ps)
                    ps = size / 8;
            }

            for(std::size_t k = 0; k < 4; ++k)
            {
                auto const& pv = track.patterns.at(pattern_array[k]);
                for(std::size_t i = 0; i < ps; ++i)
                {
                    std::array<channel_data_t, 8> penguin_pattern;
                    for(std::size_t j = 0; j < 8; ++j)
                    {
                        channel_data_t cd = pv[i*8+j].chan[k];

                        if(cd.note == -2)
                            penguin_pattern[j] = { 0, 0 };
                        else if(cd.instrument >= 0 && cd.note >= 0)
                        {
                            auto pair = penguin_instrument_map[k].emplace(
                                cd.instrument, 
                                penguin_instrument_map[k].size());
                            if(pair.second)
                            {
                                penguin_instrument_vector[k].push_back(
                                    cd.instrument);
                            }

                            penguin_pattern[j] 
                                = { cd.note, pair.first->second};
                        }
                        else
                            penguin_pattern[j] = { -1, -1 };

                    }

                    auto pair = penguin_pattern_map.emplace(
                        penguin_pattern,
                        penguin_pattern_map.size());
                    if(pair.second)
                        penguin_pattern_vector.push_back(penguin_pattern);
                    penguin_channels[k].push_back(pair.first->second);
                }
            }
        }

        std::fprintf(fp, "track_%i:\n", t);
        for(std::size_t i = 0; i < penguin_channels[0].size(); ++i)
        for(std::size_t k = 0; k < 4; ++k)
        {
            if(penguin_channels[k].size() != penguin_channels[0].size())
               throw std::runtime_error("bad size");
            std::fprintf(fp, ".addr pattern_%i\n", penguin_channels[k][i]);
        }
    }
    std::fprintf(fp, "tracks_end:\n");

    for(std::size_t i = 0; i < penguin_pattern_vector.size(); ++i)
    {
        bucket_t bucket = {};
        std::stringstream ss;

        auto const& pattern = penguin_pattern_vector[i];
        ss << "pattern_" << i << ":\n";
        ss << ".byt " << (int)pattern_mask(pattern) << '\n';
        ++bucket.size;
        for(std::size_t j = 0; j < 8; ++j)
        {
            // TODO: fix negative notes
            if(pattern[j].instrument >= 0 && pattern[j].note >= 0)
            {
                ss << ".byt " << pattern[j].instrument << ", ";
                ss << pattern[j].note << '\n';
                bucket.size += 2;
            }
        }

        bucket.string = ss.str();
        buckets.push_back(std::move(bucket));
    }

    std::map<macro_t, int> penguin_macro_map;
    std::vector<macro_t> penguin_macro_vector;

    std::map<macro_t, int> penguin_arpeggio_map;
    std::vector<macro_t> penguin_arpeggio_vector;

    // Find used sequences
    for(int k = 0; k < 4; ++k)
    for(int i = 0; i < penguin_instrument_vector[k].size(); ++i)
    {
        char const* chan = channel_name(k);
        int const j = penguin_instrument_vector.at(k).at(i);

        {
            auto it = macros.find(std::make_pair(macro_t::volume, instruments.at(j).seq_vol));
            if(it == macros.end())
            {
                std::cout << "fuck" << std::endl;
                std::cout << "seq_vol" << instruments[j].seq_vol << std::endl;
            }
            macro_t vol_duty = combine_vol_duty(
                macros.at(std::make_pair(macro_t::volume, instruments[j].seq_vol)),
                macros.at(std::make_pair(macro_t::duty, instruments[j].seq_dut)));
            auto pair = penguin_macro_map.emplace(
                vol_duty, 
                penguin_macro_map.size());
            if(pair.second)
                penguin_macro_vector.push_back(vol_duty);

            instruments[j].pseq_vol_duty = pair.first->second;
        }

        if(k != 3)
        {
            macro_t const& pit = macros.at(
                std::make_pair(macro_t::pitch, instruments[j].seq_pit));
            auto pair = penguin_macro_map.emplace(
                pit, 
                penguin_macro_map.size());
            if(pair.second)
                penguin_macro_vector.push_back(pit);

            instruments[j].pseq_pit = pair.first->second;
        }

        {
            macro_t const& arp = macros.at(
                std::make_pair(macro_t::arpeggio, instruments.at(j).seq_arp));
            auto pair = penguin_arpeggio_map.emplace(
                arp, penguin_arpeggio_map.size());
            if(pair.second)
                penguin_arpeggio_vector.push_back(arp);

            instruments[j].pseq_arp = pair.first->second;
        }
    }

    for(int k = 0; k < 4; ++k)
    {
        char const* chan = channel_name(k);

        {
            bucket_t bucket = {};
            std::stringstream ss;

            ss << chan << "_instrument_lo:\n";
            for(int i = 0; i < penguin_instrument_vector[k].size(); ++i)
            {
                ss << ".byt .lobyte(" << chan << "_instrument_";
                ss << i << "_arpeggio)\n";
                bucket.size += 1;
            }

            bucket.string = ss.str();
            buckets.push_back(std::move(bucket));
        }

        {
            bucket_t bucket = {};
            std::stringstream ss;

            ss << chan << "_instrument_hi:\n";
            for(int i = 0; i < penguin_instrument_vector[k].size(); ++i)
            {
                ss << ".byt .hibyte(" << chan << "_instrument_";
                ss << i << "_arpeggio)\n";
                bucket.size += 1;
            }

            bucket.string = ss.str();
            buckets.push_back(std::move(bucket));
        }
    }

    for(int k = 0; k < 4; ++k)
    for(int i = 0; i < penguin_instrument_vector[k].size(); ++i)
    {
        char const* chan = channel_name(k);
        int const j = penguin_instrument_vector[k][i];

        {
            macro_t const* macro 
                = &penguin_macro_vector[instruments[j].pseq_vol_duty];
            bucket_t bucket = {};
            std::stringstream ss;

            ss << chan << "_instrument_" << i << "_vol_duty:\n";
            ss << "    jsr " << chan << "_instrument_assign_return\n";
            ss << "    cpy #" << macro->sequence.size() << '\n';
            ss << "    bcc :+\n";
            ss << "    ldy #" << macro->loop << '\n';
            ss << ":   lda macro_" << instruments[j].pseq_vol_duty << ", y\n";
            ss << "    jmp " << chan << "_vol_duty_return\n";

            bucket.size += (3+2+2+2+3+3);
            bucket.string = ss.str();
            buckets.push_back(std::move(bucket));
        }

        if(k != 3)
        {
            macro_t const* macro 
                = &penguin_macro_vector[instruments[j].pseq_pit];
            bucket_t bucket = {};
            std::stringstream ss;

            ss << chan << "_instrument_" << i << "_pitch:\n";
            ss << "    jsr " << chan << "_instrument_" << i << "_vol_duty\n";
            ss << "    cpx #" << macro->sequence.size() << '\n';
            ss << "    bcc :+\n";
            ss << "    ldx #" << macro->loop << '\n';
            ss << ":   lda macro_" << instruments[j].pseq_pit << ", x\n";
            ss << "    jmp " << chan << "_pitch_return\n";

            bucket.size += (3+2+2+2+3+3);
            bucket.string = ss.str();
            buckets.push_back(std::move(bucket));
        }

        {
            macro_t const* macro 
                = &penguin_arpeggio_vector[instruments[j].pseq_arp];
            std::stringstream ss;

            ss << chan << "_instrument_" << i << "_arpeggio:\n";
            if(k != 3)
                ss << "    jsr " << chan << "_instrument_"<< i <<"_pitch\n";
            else
                ss << "    jsr " << chan << "_instrument_"<< i <<"_vol_duty\n";

            for(int i = 0; i < macro->sequence.size(); ++i)
            {
                if(i == macro->loop)
                {
                    ss << "    .byt $04, $00\n";
                    ss << "@loop:\n";
                }
                if(macro->sequence[i])
                {
                    if(k != 3)
                        ss << "    sbc #.lobyte(";
                    else
                        ss << "    axs #.lobyte(";
                    ss << (macro->sequence[i] * (k == 3 ? 1 : -2));
                    ss << ")\n";
                }
                else
                    ss << "    nop\n";
                if(i == macro->loop)
                    ss << "    jsr " << chan << "_arpeggio_return+2\n";
                else
                    ss << "    jsr " << chan << "_arpeggio_return\n";
            }
            ss << "    jmp @loop\n";

            arpeggio_string += ss.str();
        }
    }
    
    for(int i = 0; i < penguin_macro_vector.size(); ++i)
    {
        bucket_t bucket = {};
        std::stringstream ss;

        macro_t const& macro = penguin_macro_vector[i];
        ss << "macro_" << i << ":\n";
        for(int j = 0; j < macro.sequence.size(); ++j)
        {
            ss << ".byt .lobyte(" << macro.sequence[j] << ")\n";
            bucket.size += 1;
        }

        bucket.string = ss.str();
        buckets.push_back(std::move(bucket));
    }

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
    std::fprintf(fp, "%s", arpeggio_string.c_str());

    std::fprintf(fp, "tracks_lo:\n");
    for(int i = 0; i < tracks.size(); ++i)
        std::fprintf(fp, ".byt .lobyte(track_%i)\n", i);
    std::fprintf(fp, ".byt .lobyte(tracks_end)\n");

    std::fprintf(fp, "tracks_hi:\n");
    for(int i = 0; i < tracks.size(); ++i)
        std::fprintf(fp, ".byt .hibyte(track_%i)\n", i);
    std::fprintf(fp, ".byt .hibyte(tracks_end)\n");

    std::fprintf(fp, "tracks_speed:\n");
    for(int i = 0; i < tracks.size(); ++i)
        std::fprintf(fp, ".byt %i\n", tracks[i].speed);

    return 0;
}

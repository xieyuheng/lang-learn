#include <stdio.h>

typedef struct {
        int id;
        char *a, *b;
} Rule;

static int dst;
static Rule rules[0x1000], lambda, *rules_ = rules;
static char dict[0x8000], *dict_ = dict;
static char bank_a[0x4000], *prog_ = bank_a;
static char bank_b[0x4000], *outp_ = bank_b;
static char *regs[0x100];

#define spacer(c) (c <= ' ' || c == '(' || c == ')')

static char *
walk(char *s)
{
        char c;
        int depth = 0;
        if(s[0] == '(') {
                while((c = *s++)) {
                        if(c == '(') depth++;
                        if(c == ')') --depth;
                        if(!depth) return s;
                }
        }
        while((c = *s) && !spacer(c)) s++;
        return s;
}

static char *
plode(char *s)
{
        int i, depth = 0;
        char c, *ss;
        /* implode */
        if(s[0] == '(') {
                ss = walk(s);
                while(s < ss && (c = *(s++)))
                        if(!spacer(c)) *outp_++ = c;
        }
        /* explode */
        else {
                while((c = *s++) && !spacer(c))
                        *outp_++ = c, *outp_++ = ' ', *outp_++ = '(', depth++;
                for(i = 0; i < depth; i++)
                        *outp_++ = ')';
        }
        return s;
}

static int
set_reg(int r, char *b)
{
        if(regs[r]) {
                char *a = regs[r], *aa = walk(a), *bb = walk(b);
                while(a < aa && b < bb)
                        if(*a++ != *b++) return 0;
        } else
                regs[r] = b;
        return 1;
}

static void
put_reg(char r)
{
        char *s = regs[(int)r];
        if(r == '*')
                s = plode(s);
        else if(r == '~') {
                char buf;
                while(fread(&buf, 1, 1, stdin) && buf >= ' ')
                        *outp_++ = buf;
        } else if(s) {
                char *ss = walk(s);
                if(r == ':') {
                        if(*s == '(') s++, --ss;
                        while(s < ss) {
                                char c = *(s++);
                                if(c == '\\' && *(s++) == 'n') c = 0xa;
                                putc(c, stdout);
                        }
                } else
                        while((s < ss)) *outp_++ = *s++;
        } else
                *outp_++ = r;
}

static char *
match_rule(Rule *r, char *p)
{
        int i;
        char c, *a = r->a, *b = p;
        for(i = 0x21; i < 0x7f; i++)
                regs[i] = 0;
        while((c = *a)) {
                if(c == '?') {
                        if(!set_reg(*(++a), b)) return NULL;
                        a++, b = walk(b);
                        continue;
                }
                if(*a != *b) return NULL;
                a++, b++;
        }
        c = *b;
        return spacer(c) ? b : NULL;
}

static int
commit_rule(Rule *r, char *s, int create)
{
        while((*outp_++ = *s++))
                ;
        *outp_++ = 0;
        if((dst = !dst))
                prog_ = bank_b, outp_ = bank_a;
        else
                prog_ = bank_a, outp_ = bank_b;
        if(create)
                fprintf(stderr, "<> (%s) (%s)\n", r->a, r->b);
        else
                fprintf(stderr, "%02d %s\n", r->id, prog_);
        return 1;
}

static int
write_rule(Rule *r, char last, char *res)
{
        char cc, *b = r->b;
        if(!*b && last == ' ') outp_--;
        while((cc = *b++))
                if(cc == '?')
                        put_reg(*b++);
                else
                        *outp_++ = cc;
        return commit_rule(r, res, 0);
}

static char *
parse_frag(char *s)
{
        char c, *ss;
        while((c = *s) && c <= ' ') s++;
        ss = walk(s);
        if(*s == '(') s++, ss--;
        while((s < ss)) *dict_++ = *s++;
        *dict_++ = 0;
        s++;
        return s;
}

static char *
create_rule(Rule *r, int id, char *s)
{
        char c;
        r->id = id, s += 2;
        r->a = dict_, s = parse_frag(s), r->b = dict_, s = parse_frag(s);
        while((c = *s) && c <= ' ') s++;
        return s;
}

static int
rewrite(void)
{
        char c, last = 0, *s = dst ? bank_b : bank_a, *res;
        while((c = *s) && c <= ' ') s++;
        while((c = *s)) {
                if(spacer(last)) {
                        Rule *r;
                        if(s[0] == '<' && s[1] == '>') {
                                r = rules_++;
                                s = create_rule(r, rules_ - rules - 1, s);
                                return commit_rule(r, s, 1);
                        }
                        if(s[0] == '?' && s[1] == '(') {
                                r = &lambda;
                                s = create_rule(&lambda, -1, s) + 1;
                                if((res = match_rule(&lambda, s)) != NULL)
                                        return write_rule(&lambda, last, res);
                        }
                        for(r = rules; r < rules_; r++)
                                if((res = match_rule(r, s)) != NULL)
                                        return write_rule(r, last, res);
                }
                *outp_++ = last = c;
                s++;
        }
        *outp_++ = 0;
        return 0;
}

int
main(int argc, char **argv)
{
        FILE *f;
        char c, *w = bank_a;
        if(argc < 2)
                return !printf("usage: modal [-v] source.modal\n");
        if(argc < 3 && argv[1][0] == '-' && argv[1][1] == 'v')
                return !printf("Modal Interpreter, 11 Apr 2024.\n");
        if(!(f = fopen(argv[1], "r")))
                return !printf("Invalid Modal file: %s.\n", argv[1]);
        while(fread(&c, 1, 1, f)) {
                if(w > bank_a) {
                        if(c == ' ' && *(w - 1) == '(') continue;
                        if(c == ')' && *(w - 1) == ' ') w--;
                        if(c == ' ' && *(w - 1) == ' ') w--;
                }
                *w++ = c;
        }
        while(*(--w) <= ' ') *w = 0;
        fclose(f);
        while(rewrite())
                ;
        return 0;
}

#include "stdlib.h"
#include "string.h"
#include "ruby.h"

int ensure_int_str(char *str)
{
    char *ptr = str;
    int is_int_str = 1;
    while (*ptr != '\0')
    {
        if (*ptr > '9' || *ptr < '0')
            is_int_str = 0;
        ptr++;
    }

    return is_int_str;
}

enum MentionType
{
    Error,
    User,
    Role,
    Channel,
    Emoji
};

struct MentionNode
{
    char *id;
    int type;
    struct MentionNode *next;
};

void destroy_mentions(struct MentionNode *mentions)
{
    struct MentionNode *current_node;

    while (mentions->next != NULL)
    {
        current_node = mentions;
        mentions = current_node->next;

        free(current_node->id);
        free(current_node);
    }

    if (mentions->type != Error)
        free(mentions->id);
    free(mentions);
}

struct MentionNode *null_mention()
{
    struct MentionNode *mention = malloc(sizeof(struct MentionNode));
    mention->type = Error;
    mention->id = NULL;
    mention->next = NULL;
    return mention;
}

struct MentionNode *new_mention(struct MentionNode *mention, char *lab, char *rab)
{
    char *inner_ptr;
    char *id_str;
    int status = 0;
    int type = Error;
    int offset = 1;

    mention->next = NULL;
    inner_ptr = malloc(sizeof(char) * (rab - lab) - 1);
    strncpy(inner_ptr, lab + 1, (rab - lab) - 1);
    *(inner_ptr + (rab - lab) - 1) = '\0';

    switch (inner_ptr[0])
    {
    case '@':
        if (inner_ptr[1] == '!')
        {
            type = User;
            offset++;
        }
        else if (inner_ptr[1] == '&')
        {
            type = Role;
            offset++;
        }
        else
            type = User;

        id_str = malloc(sizeof(char) * (strlen(inner_ptr + offset) + 1));
        strcpy(id_str, inner_ptr + offset);
        free(inner_ptr);

        status = ensure_int_str(id_str);
        if (status)
        {
            mention->id = id_str;
            mention->type = type;
        }
        else
        {
            free(id_str);
            mention->type = Error;
        }

        break;
    case '#':
        status = ensure_int_str(inner_ptr + offset);
        id_str = malloc(sizeof(char) * (strlen(inner_ptr + offset) + 1));
        strcpy(id_str, inner_ptr + offset);
        free(inner_ptr);

        mention->id = id_str;
        if (status)
            mention->type = Channel;
        else
            mention->type = Error;
        break;
    case 'a':
    case ':':
        mention->type = Emoji;
        mention->id = inner_ptr;
        break;
    default:
        mention->type = Error;
        free(inner_ptr);
        break;
    }

    return mention;
}

void add_mention(struct MentionNode *mentions, char *lab, char *rab)
{
    struct MentionNode *mention_node = mentions;
    struct MentionNode *next_node = null_mention();

    while (mention_node->next != NULL)
        mention_node = mention_node->next;
    new_mention(next_node, lab, rab);
    if (next_node->type != Error && next_node->id != NULL)
        mention_node->next = next_node;
    else
    {
        destroy_mentions(next_node);
    }
}

char *find_closest_lab(char *src, char *rab)
{
    char *lab_ptr = rab;
    while (*lab_ptr != '<' && lab_ptr > src)
        lab_ptr--;

    if (lab_ptr == src && *lab_ptr != '<')
        return NULL;

    return lab_ptr;
}

char *find_mention(char *src, struct MentionNode *mentions)
{
    char *rab;
    char *lab;

    rab = strchr(src, '>');

    if (rab == NULL)
        return NULL;

    lab = find_closest_lab(src, rab);
    add_mention(mentions, lab, rab);
    return ++rab;
}

struct MentionNode *find_mentions(char *src)
{
    struct MentionNode *mentions = null_mention();
    char *ptr = src;
    while ((ptr = find_mention(ptr, mentions)) != NULL)
        ;
    return mentions;
}

VALUE rb_mention_to_rb_ary(struct MentionNode *node)
{
    VALUE array = rb_ary_new();

    switch (node->type)
    {
    case User:
        rb_ary_push(array, ID2SYM(rb_intern("user")));
        break;
    case Channel:
        rb_ary_push(array, ID2SYM(rb_intern("channel")));
        break;
    case Role:
        rb_ary_push(array, ID2SYM(rb_intern("role")));
        break;
    case Emoji:
        rb_ary_push(array, ID2SYM(rb_intern("emoji")));
        break;
    default:
        return Qnil;
        break;
    }
    rb_ary_push(array, rb_str_new_cstr(node->id));

    return array;
}

VALUE rb_parse_mentions(VALUE self, VALUE str)
{
    struct MentionNode *mentions;
    struct MentionNode *mention_node;
    VALUE mention;
    VALUE mention_ary = rb_ary_new();

    // Need to raise here
    if (RB_TYPE_P(str, T_STRING) == 0)
        return Qnil;

    mentions = find_mentions(StringValuePtr(str));
    mention_node = mentions;

    while ((mention_node = mention_node->next) != NULL)
    {
        mention = rb_mention_to_rb_ary(mention_node);
        if (mention != Qnil)
            rb_ary_push(mention_ary, mention);
    }
    destroy_mentions(mentions);

    return mention_ary;
}

void Init_parse_mentions()
{
    VALUE mod = rb_define_module("Discordrb");

    rb_define_module_function(mod, "parse_mentions", rb_parse_mentions, 1);
}
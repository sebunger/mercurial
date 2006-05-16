/*
 bdiff.c - efficient binary diff extension for Mercurial

 Copyright 2005 Matt Mackall <mpm@selenic.com>

 This software may be used and distributed according to the terms of
 the GNU General Public License, incorporated herein by reference.

 Based roughly on Python difflib
*/

#include <Python.h>
#include <stdlib.h>
#include <string.h>

#ifdef __hpux
#define inline
#endif

#ifdef __SUNPRO_C
# define inline
#endif 

#ifdef _WIN32
#ifdef _MSC_VER
#define inline __inline
typedef unsigned long uint32_t;
#else
#include <stdint.h>
#endif
static uint32_t htonl(uint32_t x)
{
	return ((x & 0x000000ffUL) << 24) |
		((x & 0x0000ff00UL) <<  8) |
		((x & 0x00ff0000UL) >>  8) |
		((x & 0xff000000UL) >> 24);
}
#else
#include <sys/types.h>
#include <arpa/inet.h>
#endif

struct line {
	int h, len, n, e;
	const char *l;
};

struct pos {
	int pos, len;
};

struct hunk {
	int a1, a2, b1, b2;
};

struct hunklist {
	struct hunk *base, *head;
};

static inline uint32_t rol32(uint32_t word, unsigned int shift)
{
        return (word << shift) | (word >> (32 - shift));
}

int splitlines(const char *a, int len, struct line **lr)
{
	int h, i;
	const char *p, *b = a;
	struct line *l;

	/* count the lines */
	i = 1; /* extra line for sentinel */
	for (p = a; p < a + len; p++)
		if (*p == '\n' || p == a + len - 1)
			i++;

	*lr = l = (struct line *)malloc(sizeof(struct line) * i);
	if (!l)
		return -1;

	/* build the line array and calculate hashes */
	h = 0;
	for (p = a; p < a + len; p++) {
		h = *p + rol32(h, 7); /* a simple hash from GNU diff */
		if (*p == '\n' || p == a + len - 1) {
			l->len = p - b + 1;
			l->h = h * l->len;
			l->l = b;
			l->n = -1;
			l++;
			b = p + 1;
			h = 0;
		}
	}

	/* set up a sentinel */
	l->h = l->len = 0;
	l->l = a + len;
	return i - 1;
}

int inline cmp(struct line *a, struct line *b)
{
	return a->h != b->h || a->len != b->len || memcmp(a->l, b->l, a->len);
}

static int equatelines(struct line *a, int an, struct line *b, int bn)
{
	int i, j, buckets = 1, t;
	struct pos *h;

	/* build a hash table of the next highest power of 2 */
	while (buckets < bn + 1)
		buckets *= 2;

	h = (struct pos *)malloc(buckets * sizeof(struct pos));
	buckets = buckets - 1;
	if (!h)
		return 0;

	/* clear the hash table */
	for (i = 0; i <= buckets; i++) {
		h[i].pos = -1;
		h[i].len = 0;
	}

	/* add lines to the hash table chains */
	for (i = bn - 1; i >= 0; i--) {
		/* find the equivalence class */
		for (j = b[i].h & buckets; h[j].pos != -1;
		     j = (j + 1) & buckets)
			if (!cmp(b + i, b + h[j].pos))
				break;

		/* add to the head of the equivalence class */
		b[i].n = h[j].pos;
		b[i].e = j;
		h[j].pos = i;
		h[j].len++; /* keep track of popularity */
	}

	/* compute popularity threshold */
	t = (bn >= 200) ? bn / 100 : bn + 1;

	/* match items in a to their equivalence class in b */
	for (i = 0; i < an; i++) {
		/* find the equivalence class */
		for (j = a[i].h & buckets; h[j].pos != -1;
		     j = (j + 1) & buckets)
			if (!cmp(a + i, b + h[j].pos))
				break;

		a[i].e = j; /* use equivalence class for quick compare */
		if (h[j].len <= t)
			a[i].n = h[j].pos; /* point to head of match list */
		else
			a[i].n = -1; /* too popular */
	}

	/* discard hash tables */
	free(h);
	return 1;
}

static int longest_match(struct line *a, struct line *b, struct pos *pos,
			 int a1, int a2, int b1, int b2, int *omi, int *omj)
{
	int mi = a1, mj = b1, mk = 0, mb = 0, i, j, k;

	for (i = a1; i < a2; i++) {
		/* skip things before the current block */
		for (j = a[i].n; j != -1 && j < b1; j = b[j].n)
			;

		/* loop through all lines match a[i] in b */
		for (; j != -1 && j < b2; j = b[j].n) {
			/* does this extend an earlier match? */
			if (i > a1 && j > b1 && pos[j - 1].pos == i - 1)
				k = pos[j - 1].len + 1;
			else
				k = 1;
			pos[j].pos = i;
			pos[j].len = k;

			/* best match so far? */
			if (k > mk) {
				mi = i;
				mj = j;
				mk = k;
			}
		}
	}

	if (mk) {
		mi = mi - mk + 1;
		mj = mj - mk + 1;
	}

	/* expand match to include neighboring popular lines */
	while (mi - mb > a1 && mj - mb > b1 &&
	       a[mi - mb - 1].e == b[mj - mb - 1].e)
		mb++;
	while (mi + mk < a2 && mj + mk < b2 &&
	       a[mi + mk].e == b[mj + mk].e)
		mk++;

	*omi = mi - mb;
	*omj = mj - mb;
	return mk + mb;
}

static void recurse(struct line *a, struct line *b, struct pos *pos,
		    int a1, int a2, int b1, int b2, struct hunklist *l)
{
	int i, j, k;

	/* find the longest match in this chunk */
	k = longest_match(a, b, pos, a1, a2, b1, b2, &i, &j);
	if (!k)
		return;

	/* and recurse on the remaining chunks on either side */
	recurse(a, b, pos, a1, i, b1, j, l);
	l->head->a1 = i;
	l->head->a2 = i + k;
	l->head->b1 = j;
	l->head->b2 = j + k;
	l->head++;
	recurse(a, b, pos, i + k, a2, j + k, b2, l);
}

static struct hunklist diff(struct line *a, int an, struct line *b, int bn)
{
	struct hunklist l;
	struct pos *pos;
	int t;

	/* allocate and fill arrays */
	t = equatelines(a, an, b, bn);
	pos = (struct pos *)calloc(bn, sizeof(struct pos));
	/* we can't have more matches than lines in the shorter file */
	l.head = l.base = (struct hunk *)malloc(sizeof(struct hunk) *
	                                        ((an<bn ? an:bn) + 1));

	if (pos && l.base && t) {
		/* generate the matching block list */
		recurse(a, b, pos, 0, an, 0, bn, &l);
		l.head->a1 = an;
		l.head->b1 = bn;
		l.head++;
	}

	free(pos);
	return l;
}

static PyObject *blocks(PyObject *self, PyObject *args)
{
	PyObject *sa, *sb, *rl = NULL, *m;
	struct line *a, *b;
	struct hunklist l = {NULL, NULL};
	struct hunk *h;
	int an, bn, pos = 0;

	if (!PyArg_ParseTuple(args, "SS:bdiff", &sa, &sb))
		return NULL;

	an = splitlines(PyString_AsString(sa), PyString_Size(sa), &a);
	bn = splitlines(PyString_AsString(sb), PyString_Size(sb), &b);
	if (!a || !b)
		goto nomem;

	l = diff(a, an, b, bn);
	rl = PyList_New(l.head - l.base);
	if (!l.head || !rl)
		goto nomem;

	for (h = l.base; h != l.head; h++) {
		m = Py_BuildValue("iiii", h->a1, h->a2, h->b1, h->b2);
		PyList_SetItem(rl, pos, m);
		pos++;
	}

nomem:
	free(a);
	free(b);
	free(l.base);
	return rl ? rl : PyErr_NoMemory();
}

static PyObject *bdiff(PyObject *self, PyObject *args)
{
	PyObject *sa, *sb, *result = NULL;
	struct line *al, *bl;
	struct hunklist l = {NULL, NULL};
	struct hunk *h;
	char encode[12], *rb;
	int an, bn, len = 0, la = 0, lb = 0;

	if (!PyArg_ParseTuple(args, "SS:bdiff", &sa, &sb))
		return NULL;

	an = splitlines(PyString_AsString(sa), PyString_Size(sa), &al);
	bn = splitlines(PyString_AsString(sb), PyString_Size(sb), &bl);
	if (!al || !bl)
		goto nomem;

	l = diff(al, an, bl, bn);
	if (!l.head)
		goto nomem;

	/* calculate length of output */
	for (h = l.base; h != l.head; h++) {
		if (h->a1 != la || h->b1 != lb)
			len += 12 + bl[h->b1].l - bl[lb].l;
		la = h->a2;
		lb = h->b2;
	}

	result = PyString_FromStringAndSize(NULL, len);
	if (!result)
		goto nomem;

	/* build binary patch */
	rb = PyString_AsString(result);
	la = lb = 0;

	for (h = l.base; h != l.head; h++) {
		if (h->a1 != la || h->b1 != lb) {
			len = bl[h->b1].l - bl[lb].l;
			*(uint32_t *)(encode)     = htonl(al[la].l - al->l);
			*(uint32_t *)(encode + 4) = htonl(al[h->a1].l - al->l);
			*(uint32_t *)(encode + 8) = htonl(len);
			memcpy(rb, encode, 12);
			memcpy(rb + 12, bl[lb].l, len);
			rb += 12 + len;
		}
		la = h->a2;
		lb = h->b2;
	}

nomem:
	free(al);
	free(bl);
	free(l.base);
	return result ? result : PyErr_NoMemory();
}

static char mdiff_doc[] = "Efficient binary diff.";

static PyMethodDef methods[] = {
	{"bdiff", bdiff, METH_VARARGS, "calculate a binary diff\n"},
	{"blocks", blocks, METH_VARARGS, "find a list of matching lines\n"},
	{NULL, NULL}
};

PyMODINIT_FUNC initbdiff(void)
{
	Py_InitModule3("bdiff", methods, mdiff_doc);
}

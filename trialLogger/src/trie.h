#ifndef _TRIE_H_INCLUDED_
#define _TRIE_H_INCLUDED_

// A simple implementation of a Trie data structure with 256 branches at each level
// O(m) lookup, insert times where m is length of string

#define TRIEFANOUT 256

typedef struct Trie {
	void* value; 
	struct Trie* edges[TRIEFANOUT];
	struct Trie* parent;
	unsigned indexInParent;
} Trie;

Trie* trie_create();
void trie_add(Trie *node, const char *str, void *value);
// execute the callback on all values and free node
void trie_flush(Trie *node, void (*callback)(void*));

Trie* trie_find(Trie *node, const char *str);
void* trie_lookup(Trie *node, const char *str); 

// count the number of non-NULL valued trie nodes in the trie
unsigned trie_count(Trie *node);
//sum the results of calling accumFn on all non-NULL values in the trie
unsigned trie_accumulate(Trie *node, unsigned (*accumFn)(void*));

// call fn over all my occupied edges
void trie_callOnEach(Trie *node, void (*fn)(void *));

// trie iteration, start with root node and then call trie_get_next
Trie* trie_get_next(Trie *node);

// get the first non-empty value in trie
Trie* trie_get_first(Trie *node);

#endif /* _TRIE_H_INCLUDED_ */

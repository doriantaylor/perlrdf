#include "materialize.h"

// prototypes
int _hx_materialize_join_vb_names ( hx_variablebindings* lhs, hx_variablebindings* rhs, char*** merged_names, int* size );
int _hx_materialize_join_iter_names ( hx_variablebindings_iter* lhs, hx_variablebindings_iter* rhs, char*** merged_names, int* size );
int _hx_materialize_join_names ( char** lhs_names, int lhs_size, char** rhs_names, int rhs_size, char*** merged_names, int* size );

// implementations

int _hx_materialize_iter_vb_finished ( void* data ) {
//	fprintf( stderr, "*** _hx_mergejoin_iter_vb_finished\n" );
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;

//	fprintf( stderr, "- finished == %d\n", info->finished );
	return info->finished;
}

int _hx_materialize_iter_vb_current ( void* data, void* results ) {
//	fprintf( stderr, "*** _hx_materialize_iter_vb_current\n" );
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	
	hx_variablebindings** b	= (hx_variablebindings**) results;
	*b	= info->bindings[ info->index ];
	return 0;
}

int _hx_materialize_iter_vb_next ( void* data ) {
// 	fprintf( stderr, "*** _hx_materialize_iter_vb_next\n" );
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	
	info->index++;
	if (info->index >= info->length) {
		info->finished	= 1;
		return 1;
	} else {
		return 0;
	}
}

int _hx_materialize_iter_vb_free ( void* data ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	for (int i = 0; i < info->length; i++) {
		hx_free_variablebindings( info->bindings[ i ], 0 );
	}
	free( info->bindings );
	free( info->names );
	free( info );
	return 0;
}

int _hx_materialize_iter_vb_size ( void* data ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	return info->size;
}

char** _hx_materialize_iter_vb_names ( void* data ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	return info->names;
}

int _hx_materialize_iter_sorted_by ( void* data, int index ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	return (index == info->sorted_by);
}

hx_variablebindings_iter* hx_new_materialize_iter ( hx_variablebindings_iter* iter ) {
	int size		= hx_variablebindings_iter_size( iter );
	char** _names	= hx_variablebindings_iter_names( iter );
	char** names	= (char**) calloc( size, sizeof( char* ) );
	int sorted_by	= -1;
	for (int i = 0; i < size; i++) {
		names[i]	= _names[i];
		if (hx_variablebindings_iter_is_sorted_by_index( iter, i )) {
			sorted_by	= i;
		}
	}
	
	hx_variablebindings_iter_vtable* vtable	= malloc( sizeof( hx_variablebindings_iter_vtable ) );
	vtable->finished	= _hx_materialize_iter_vb_finished;
	vtable->current		= _hx_materialize_iter_vb_current;
	vtable->next		= _hx_materialize_iter_vb_next;
	vtable->free		= _hx_materialize_iter_vb_free;
	vtable->names		= _hx_materialize_iter_vb_names;
	vtable->size		= _hx_materialize_iter_vb_size;
	vtable->sorted_by	= _hx_materialize_iter_sorted_by;
	
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) calloc( 1, sizeof( _hx_materialize_iter_vb_info ) );
	info->finished	= 0;
	info->size		= size;
	info->index		= 0;
	info->sorted_by	= sorted_by;
	
	info->length	= 0;
	int alloc		= 32;
	hx_variablebindings** bindings	= calloc( alloc, sizeof( hx_variablebindings* ) );
	
	while (!hx_variablebindings_iter_finished( iter )) {
		hx_variablebindings* b;
		hx_variablebindings_iter_current( iter, &b );
		bindings[ info->length++ ]	= b;
		if (info->length >= alloc) {
			alloc	= alloc * 2;
			hx_variablebindings** newbindings	= calloc( alloc, sizeof( hx_variablebindings* ) );
			if (newbindings == NULL) {
				fprintf( stderr, "*** allocating space for %d materialized bindings failed\n", alloc );
				return NULL;
			}
			for (int i = 0; i < info->length; i++) {
				newbindings[i]	= bindings[i];
			}
			free( bindings );
			bindings	= newbindings;
		}
		hx_variablebindings_iter_next( iter );
	}
	hx_free_variablebindings_iter( iter, 0 );
	hx_variablebindings_iter* miter	= hx_variablebindings_new_iter( vtable, (void*) info );
	return miter;
}

int hx_materialize_sort_iter ( hx_variablebindings_iter* iter, int index ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) iter->ptr;
	_hx_materialize_bindings_sort_info* sorted	= calloc( info->length, sizeof( _hx_materialize_bindings_sort_info ) );
	if (sorted == NULL) {
		fprintf( stderr, "*** allocating space for sorting materialized bindings failed\n" );
		return 1;
	}
	
	for (int i = 0; i < info->length; i++) {
		sorted[i].index		= index;
		sorted[i].binding	= info->bindings[i];
	}
	
	qsort( sorted, info->length, sizeof( _hx_materialize_bindings_sort_info ), _hx_materialize_cmp_bindings );
	for (int i = 0; i < info->length; i++) {
		info->bindings[i]	= sorted[i].binding;
	}
	info->sorted_by	= index;
	return 0;
}

int _hx_materialize_cmp_bindings ( const void* _a, const void* _b ) {
	_hx_materialize_bindings_sort_info* a	= (_hx_materialize_bindings_sort_info*) _a;
	_hx_materialize_bindings_sort_info* b	= (_hx_materialize_bindings_sort_info*) _b;
	hx_node_id na	= hx_variablebindings_node_for_binding( a->binding, a->index );
	hx_node_id nb	= hx_variablebindings_node_for_binding( b->binding, b->index );
	if (na < nb) {
		return -1;
	} else if (na > nb) {
		return 1;
	} else {
		return 0;
	}
}
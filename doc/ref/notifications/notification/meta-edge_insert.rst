.. _edge_insert:

edge_insert
^^^^^^^^^^^

An edge has been inserted. 
Note that the Context for this notification does not have the user who 
created the edge. 


Type: 
    :ref:`notification-notify`

Return: 
    return value is ignored

``#edge_insert{}`` properties:
    - subject_id: ``m_rsc:resource()``
    - predicate: ``atom``
    - object_id: ``m_rsc:resource()``
    - edge_id: ``pos_integer``

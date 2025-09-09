/**
 * Query builder utilities for common database patterns
 */

/**
 * Build a dynamic WHERE clause with parameters
 * @param {Object} filters - Key-value pairs for filtering
 * @param {Array} validColumns - Array of valid column names
 * @returns {Object} {query, params, paramCount}
 */
function buildWhereClause(filters, validColumns = []) {
  let query = 'WHERE 1=1';
  const params = [];
  let paramCount = 0;

  for (const [key, value] of Object.entries(filters)) {
    if (value != null && (validColumns.length === 0 || validColumns.includes(key))) {
      params.push(value);
      query += ` AND ${key} = $${++paramCount}`;
    }
  }

  return { query, params, paramCount };
}

/**
 * Add pagination to a query
 * @param {string} baseQuery - The base query
 * @param {Array} baseParams - Existing parameters
 * @param {number} limit - Number of records to return
 * @param {number} offset - Number of records to skip
 * @returns {Object} {query, params}
 */
function addPagination(baseQuery, baseParams, limit = 20, offset = 0) {
  const params = [...baseParams];
  let paramCount = baseParams.length;
  
  const query = baseQuery + 
    ` LIMIT $${++paramCount}` + 
    ` OFFSET $${++paramCount}`;
  
  params.push(parseInt(limit), parseInt(offset));
  
  return { query, params };
}

/**
 * Build a count query from a base query
 * @param {string} baseQuery - The base query (should include WHERE clause)
 * @param {Array} params - Parameters for the WHERE clause
 * @returns {Object} {query, params}
 */
function buildCountQuery(baseQuery, params) {
  // Extract the WHERE clause from the base query
  const whereMatch = baseQuery.match(/WHERE .+?(?= ORDER BY| LIMIT| OFFSET|$)/i);
  const whereClause = whereMatch ? whereMatch[0] : 'WHERE 1=1';
  
  return {
    query: `SELECT COUNT(*) FROM user_feedback ${whereClause}`,
    params
  };
}

module.exports = {
  buildWhereClause,
  addPagination,
  buildCountQuery
};
import React, { useState, useEffect, useCallback } from 'react';
import './App.css';

const API_URL = '/api';

function App() {
  const [tasks, setTasks] = useState([]);
  const [categories, setCategories] = useState([]);
  const [stats, setStats] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Form state
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    priority: 'medium',
    category: 'general',
    due_date: ''
  });
  const [editingTask, setEditingTask] = useState(null);

  // Filter state
  const [filterCategory, setFilterCategory] = useState('all');
  const [filterPriority, setFilterPriority] = useState('all');
  const [filterCompleted, setFilterCompleted] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');

  // Fetch data on component mount
  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = useCallback(async () => {
    try {
      setLoading(true);
      const [tasksRes, categoriesRes, statsRes] = await Promise.all([
        fetch(`${API_URL}/tasks`),
        fetch(`${API_URL}/categories`),
        fetch(`${API_URL}/stats`)
      ]);

      const tasksData = await tasksRes.json();
      const categoriesData = await categoriesRes.json();
      const statsData = await statsRes.json();

      console.log('Fetched tasks:', tasksData);
      console.log('Tasks array:', tasksData.tasks);

      setTasks(tasksData.tasks || []);
      setCategories(categoriesData.categories || []);
      setStats(statsData);
      setError(null);
    } catch (err) {
      setError('Failed to fetch data. Make sure the backend API is running.');
      console.error('Error fetching data:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!formData.title.trim()) {
      setError('Task title is required');
      return;
    }

    try {
      const url = editingTask
        ? `${API_URL}/tasks/${editingTask.id}`
        : `${API_URL}/tasks`;

      const method = editingTask ? 'PUT' : 'POST';

      const response = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });

      if (response.ok) {
        await fetchData();
        resetForm();
        setError(null);
      } else {
        throw new Error('Failed to save task');
      }
    } catch (err) {
      setError('Failed to save task');
      console.error('Error saving task:', err);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this task?')) return;

    try {
      const response = await fetch(`${API_URL}/tasks/${id}`, {
        method: 'DELETE'
      });

      if (response.ok) {
        await fetchData();
        setError(null);
      } else {
        throw new Error('Failed to delete task');
      }
    } catch (err) {
      setError('Failed to delete task');
      console.error('Error deleting task:', err);
    }
  };

  const handleToggleComplete = async (task) => {
    try {
      const response = await fetch(`${API_URL}/tasks/${task.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...task, completed: !task.completed })
      });

      if (response.ok) {
        await fetchData();
        setError(null);
      } else {
        throw new Error('Failed to update task');
      }
    } catch (err) {
      setError('Failed to update task');
      console.error('Error updating task:', err);
    }
  };

  const handleEdit = (task) => {
    setEditingTask(task);
    setFormData({
      title: task.title,
      description: task.description || '',
      priority: task.priority,
      category: task.category,
      due_date: task.due_date ? task.due_date.split('T')[0] : ''
    });
    setShowForm(true);
  };

  const resetForm = () => {
    setFormData({
      title: '',
      description: '',
      priority: 'medium',
      category: 'general',
      due_date: ''
    });
    setEditingTask(null);
    setShowForm(false);
  };

  const filteredTasks = tasks.filter(task => {
    const matchesCategory = filterCategory === 'all' || task.category === filterCategory;
    const matchesPriority = filterPriority === 'all' || task.priority === filterPriority;
    const matchesCompleted = filterCompleted === 'all' ||
      (filterCompleted === 'completed' && task.completed) ||
      (filterCompleted === 'pending' && !task.completed);
    const matchesSearch = !searchTerm ||
      task.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (task.description && task.description.toLowerCase().includes(searchTerm.toLowerCase()));

    return matchesCategory && matchesPriority && matchesCompleted && matchesSearch;
  });

  const getPriorityColor = (priority) => {
    switch (priority) {
      case 'high': return '#EF4444';
      case 'medium': return '#F59E0B';
      case 'low': return '#10B981';
      default: return '#6B7280';
    }
  };

  if (loading) {
    return (
      <div className="app">
        <div className="loading">Loading...</div>
      </div>
    );
  }

  return (
    <div className="app">
      <header className="header">
        <div className="container">
          <h1>📋 Task Manager</h1>
          <p>Organize your work efficiently</p>
        </div>
      </header>

      {error && (
        <div className="error-banner">
          {error}
          <button onClick={() => setError(null)}>×</button>
        </div>
      )}

      <div className="container">
        {/* Statistics */}
        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-value">{stats.total_tasks || 0}</div>
            <div className="stat-label">Total Tasks</div>
          </div>
          <div className="stat-card">
            <div className="stat-value">{stats.completed_tasks || 0}</div>
            <div className="stat-label">Completed</div>
          </div>
          <div className="stat-card">
            <div className="stat-value">{stats.pending_tasks || 0}</div>
            <div className="stat-label">Pending</div>
          </div>
          <div className="stat-card">
            <div className="stat-value">{stats.completion_rate || 0}%</div>
            <div className="stat-label">Completion Rate</div>
          </div>
        </div>

        {/* Controls */}
        <div className="controls">
          <button
            className="btn btn-primary"
            onClick={() => setShowForm(!showForm)}
          >
            {showForm ? '✕ Cancel' : '+ Add Task'}
          </button>

          <input
            type="text"
            className="search-input"
            placeholder="Search tasks..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>

        {/* Filters */}
        <div className="filters">
          <select value={filterCategory} onChange={(e) => setFilterCategory(e.target.value)}>
            <option value="all">All Categories</option>
            {categories.map(cat => (
              <option key={cat.id} value={cat.name.toLowerCase()}>
                {cat.name}
              </option>
            ))}
          </select>

          <select value={filterPriority} onChange={(e) => setFilterPriority(e.target.value)}>
            <option value="all">All Priorities</option>
            <option value="high">High</option>
            <option value="medium">Medium</option>
            <option value="low">Low</option>
          </select>

          <select value={filterCompleted} onChange={(e) => setFilterCompleted(e.target.value)}>
            <option value="all">All Status</option>
            <option value="pending">Pending</option>
            <option value="completed">Completed</option>
          </select>
        </div>

        {/* Task Form */}
        {showForm && (
          <div className="task-form">
            <h3>{editingTask ? 'Edit Task' : 'New Task'}</h3>
            <form onSubmit={handleSubmit}>
              <input
                type="text"
                placeholder="Task title *"
                required
                value={formData.title}
                onChange={(e) => setFormData({...formData, title: e.target.value})}
              />

              <textarea
                placeholder="Description (optional)"
                value={formData.description}
                onChange={(e) => setFormData({...formData, description: e.target.value})}
              />

              <div className="form-row">
                <select
                  value={formData.priority}
                  onChange={(e) => setFormData({...formData, priority: e.target.value})}
                >
                  <option value="low">Low Priority</option>
                  <option value="medium">Medium Priority</option>
                  <option value="high">High Priority</option>
                </select>

                <select
                  value={formData.category}
                  onChange={(e) => setFormData({...formData, category: e.target.value})}
                >
                  {categories.map(cat => (
                    <option key={cat.id} value={cat.name.toLowerCase()}>
                      {cat.name}
                    </option>
                  ))}
                </select>

                <input
                  type="date"
                  value={formData.due_date}
                  onChange={(e) => setFormData({...formData, due_date: e.target.value})}
                />
              </div>

              <div className="form-actions">
                <button type="submit" className="btn btn-primary">
                  {editingTask ? 'Update Task' : 'Create Task'}
                </button>
                <button type="button" className="btn btn-secondary" onClick={resetForm}>
                  Cancel
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Task List */}
        <div className="task-list">
          {filteredTasks.length === 0 ? (
            <div className="empty-state">
              <p>No tasks found. Create your first task!</p>
            </div>
          ) : (
            filteredTasks.map(task => (
              <div key={task.id} className={`task-card ${task.completed ? 'completed' : ''}`}>
                <div className="task-header">
                  <input
                    type="checkbox"
                    checked={task.completed}
                    onChange={() => handleToggleComplete(task)}
                  />
                  <h3>{task.title}</h3>
                  <span
                    className="priority-badge"
                    style={{ backgroundColor: getPriorityColor(task.priority) }}
                  >
                    {task.priority}
                  </span>
                </div>

                {task.description && (
                  <p className="task-description">{task.description}</p>
                )}

                <div className="task-footer">
                  <span className="category-badge">{task.category}</span>
                  {task.due_date && (
                    <span className="due-date">
                      📅 {new Date(task.due_date).toLocaleDateString()}
                    </span>
                  )}
                  <div className="task-actions">
                    <button
                      onClick={() => handleEdit(task)}
                      className="btn-icon"
                      title="Edit task"
                    >
                      ✏️
                    </button>
                    <button
                      onClick={() => handleDelete(task.id)}
                      className="btn-icon delete"
                      title="Delete task"
                    >
                      🗑️
                    </button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      <footer className="footer">
        <p>Task Manager v1.0 | Deployed with Terraform + Ansible</p>
      </footer>
    </div>
  );
}

export default App;

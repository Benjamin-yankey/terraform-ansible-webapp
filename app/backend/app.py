#!/usr/bin/env python3
"""
Task Manager API - Flask Backend
Production-ready REST API for task management
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import os
import logging
from logging.handlers import RotatingFileHandler

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///tasks.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['JSON_SORT_KEYS'] = False

# Initialize database
db = SQLAlchemy(app)

# Configure logging
if not app.debug:
    if not os.path.exists('logs'):
        os.mkdir('logs')
    file_handler = RotatingFileHandler('logs/taskmanager.log', maxBytes=10240, backupCount=10)
    file_handler.setFormatter(logging.Formatter(
        '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
    ))
    file_handler.setLevel(logging.INFO)
    app.logger.addHandler(file_handler)
    app.logger.setLevel(logging.INFO)
    app.logger.info('Task Manager API startup')

# Database Models
class Task(db.Model):
    """Task model for database"""
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text)
    completed = db.Column(db.Boolean, default=False)
    priority = db.Column(db.String(20), default='medium')  # low, medium, high
    category = db.Column(db.String(50), default='general')
    due_date = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        """Convert task to dictionary"""
        return {
            'id': self.id,
            'title': self.title,
            'description': self.description,
            'completed': self.completed,
            'priority': self.priority,
            'category': self.category,
            'due_date': self.due_date.isoformat() if self.due_date else None,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }

class Category(db.Model):
    """Category model for task organization"""
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False)
    color = db.Column(db.String(7), default='#3B82F6')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'color': self.color,
            'created_at': self.created_at.isoformat()
        }

# Create tables
with app.app_context():
    db.create_all()
    # Add default categories if none exist
    if Category.query.count() == 0:
        default_categories = [
            Category(name='Work', color='#3B82F6'),
            Category(name='Personal', color='#10B981'),
            Category(name='Shopping', color='#F59E0B'),
            Category(name='Health', color='#EF4444'),
            Category(name='General', color='#6B7280')
        ]
        db.session.add_all(default_categories)
        db.session.commit()

# API Routes

@app.route('/')
def index():
    """API information endpoint"""
    return jsonify({
        'name': 'Task Manager API',
        'version': '1.0.0',
        'status': 'running',
        'endpoints': {
            'tasks': '/api/tasks',
            'categories': '/api/categories',
            'health': '/api/health',
            'stats': '/api/stats'
        }
    })

@app.route('/api/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'database': 'connected'
    })

@app.route('/api/stats')
def stats():
    """Get task statistics"""
    total = Task.query.count()
    completed = Task.query.filter_by(completed=True).count()
    pending = total - completed
    
    return jsonify({
        'total_tasks': total,
        'completed_tasks': completed,
        'pending_tasks': pending,
        'completion_rate': round((completed / total * 100) if total > 0 else 0, 2)
    })

# Task CRUD Operations

@app.route('/api/tasks', methods=['GET'])
def get_tasks():
    """Get all tasks with optional filtering"""
    try:
        # Query parameters for filtering
        category = request.args.get('category')
        priority = request.args.get('priority')
        completed = request.args.get('completed')
        search = request.args.get('search')
        
        query = Task.query
        
        if category:
            query = query.filter_by(category=category)
        if priority:
            query = query.filter_by(priority=priority)
        if completed is not None:
            completed_bool = completed.lower() == 'true'
            query = query.filter_by(completed=completed_bool)
        if search:
            query = query.filter(Task.title.contains(search) | Task.description.contains(search))
        
        tasks = query.order_by(Task.created_at.desc()).all()
        
        return jsonify({
            'success': True,
            'count': len(tasks),
            'tasks': [task.to_dict() for task in tasks]
        })
    except Exception as e:
        app.logger.error(f'Error fetching tasks: {str(e)}')
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/tasks/<int:task_id>', methods=['GET'])
def get_task(task_id):
    """Get a specific task by ID"""
    task = Task.query.get_or_404(task_id)
    return jsonify({
        'success': True,
        'task': task.to_dict()
    })

@app.route('/api/tasks', methods=['POST'])
def create_task():
    """Create a new task"""
    try:
        data = request.get_json()
        
        # Validation
        if not data or not data.get('title'):
            return jsonify({'success': False, 'error': 'Title is required'}), 400
        
        # Parse due date if provided
        due_date = None
        if data.get('due_date'):
            try:
                due_date = datetime.fromisoformat(data['due_date'].replace('Z', '+00:00'))
            except ValueError:
                return jsonify({'success': False, 'error': 'Invalid date format'}), 400
        
        task = Task(
            title=data['title'],
            description=data.get('description', ''),
            priority=data.get('priority', 'medium'),
            category=data.get('category', 'general'),
            due_date=due_date
        )
        
        db.session.add(task)
        db.session.commit()
        
        app.logger.info(f'Task created: {task.title}')
        
        return jsonify({
            'success': True,
            'message': 'Task created successfully',
            'task': task.to_dict()
        }), 201
    except Exception as e:
        db.session.rollback()
        app.logger.error(f'Error creating task: {str(e)}')
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    """Update an existing task"""
    try:
        task = Task.query.get_or_404(task_id)
        data = request.get_json()
        
        if 'title' in data:
            task.title = data['title']
        if 'description' in data:
            task.description = data['description']
        if 'completed' in data:
            task.completed = data['completed']
        if 'priority' in data:
            task.priority = data['priority']
        if 'category' in data:
            task.category = data['category']
        if 'due_date' in data:
            if data['due_date']:
                task.due_date = datetime.fromisoformat(data['due_date'].replace('Z', '+00:00'))
            else:
                task.due_date = None
        
        task.updated_at = datetime.utcnow()
        db.session.commit()
        
        app.logger.info(f'Task updated: {task.title}')
        
        return jsonify({
            'success': True,
            'message': 'Task updated successfully',
            'task': task.to_dict()
        })
    except Exception as e:
        db.session.rollback()
        app.logger.error(f'Error updating task: {str(e)}')
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    """Delete a task"""
    try:
        task = Task.query.get_or_404(task_id)
        db.session.delete(task)
        db.session.commit()
        
        app.logger.info(f'Task deleted: {task.title}')
        
        return jsonify({
            'success': True,
            'message': 'Task deleted successfully'
        })
    except Exception as e:
        db.session.rollback()
        app.logger.error(f'Error deleting task: {str(e)}')
        return jsonify({'success': False, 'error': str(e)}), 500

# Category Routes

@app.route('/api/categories', methods=['GET'])
def get_categories():
    """Get all categories"""
    categories = Category.query.all()
    return jsonify({
        'success': True,
        'categories': [cat.to_dict() for cat in categories]
    })

@app.route('/api/categories', methods=['POST'])
def create_category():
    """Create a new category"""
    try:
        data = request.get_json()
        
        if not data or not data.get('name'):
            return jsonify({'success': False, 'error': 'Name is required'}), 400
        
        category = Category(
            name=data['name'],
            color=data.get('color', '#3B82F6')
        )
        
        db.session.add(category)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'category': category.to_dict()
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500

# Error handlers

@app.errorhandler(404)
def not_found(error):
    return jsonify({'success': False, 'error': 'Resource not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    return jsonify({'success': False, 'error': 'Internal server error'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
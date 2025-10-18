"""
Test suite for database seeding and maintenance functionality.

Tests:
- Seeding scripts (PhishTank, FTC, manual data)
- Admin API endpoints
- Archival logic
- Analytics endpoint

Story: 8.12 - Database Seeding & Maintenance
"""

import pytest
import asyncio
from unittest.mock import Mock, patch, AsyncMock, MagicMock
from datetime import datetime, timedelta, timezone
import json

# Test seeding functionality
class TestScamDatabaseSeeder:
    """Test seeding scripts."""
    
    @pytest.mark.asyncio
    async def test_phishtank_seeding(self):
        """Test PhishTank data seeding."""
        from scripts.seed_scam_db import ScamDatabaseSeeder
        
        # Mock PhishTank API response
        mock_phishtank_data = [
            {
                'phish_id': '12345',
                'url': 'http://scam-site.com/login',
                'submission_time': '2025-10-18T10:00:00+00:00',
                'verified': 'yes'
            },
            {
                'phish_id': '12346',
                'url': 'http://fake-bank.com',
                'submission_time': '2025-10-18T11:00:00+00:00',
                'verified': 'yes'
            }
        ]
        
        with patch('httpx.AsyncClient') as mock_client:
            # Mock the HTTP response
            mock_response = Mock()
            mock_response.json.return_value = mock_phishtank_data
            mock_response.raise_for_status = Mock()
            
            mock_client_instance = AsyncMock()
            mock_client_instance.__aenter__.return_value = mock_client_instance
            mock_client_instance.__aexit__.return_value = None
            mock_client_instance.get.return_value = mock_response
            mock_client.return_value = mock_client_instance
            
            # Mock the scam database tool
            with patch('scripts.seed_scam_db.get_scam_database_tool') as mock_tool:
                mock_tool_instance = Mock()
                mock_tool_instance.add_report.return_value = True
                mock_tool.return_value = mock_tool_instance
                
                seeder = ScamDatabaseSeeder()
                await seeder.seed_from_phishtank(limit=2)
                
                # Verify stats
                assert seeder.stats['phishtank_added'] == 2
                assert seeder.stats['phishtank_duplicates'] == 0
                
                # Verify add_report was called correctly
                assert mock_tool_instance.add_report.call_count == 2
                
                # Check first call
                first_call = mock_tool_instance.add_report.call_args_list[0]
                assert first_call[1]['entity_type'] == 'url'
                assert 'scam-site.com' in first_call[1]['entity_value']
                assert first_call[1]['evidence']['source'] == 'PhishTank'
    
    @pytest.mark.asyncio
    async def test_phishtank_duplicate_handling(self):
        """Test that duplicates are handled correctly."""
        from scripts.seed_scam_db import ScamDatabaseSeeder
        
        mock_data = [
            {
                'phish_id': '1',
                'url': 'http://scam.com',
                'submission_time': '2025-10-18T10:00:00+00:00',
                'verified': 'yes'
            }
        ]
        
        with patch('httpx.AsyncClient') as mock_client:
            mock_response = Mock()
            mock_response.json.return_value = mock_data
            mock_response.raise_for_status = Mock()
            
            mock_client_instance = AsyncMock()
            mock_client_instance.__aenter__.return_value = mock_client_instance
            mock_client_instance.__aexit__.return_value = None
            mock_client_instance.get.return_value = mock_response
            mock_client.return_value = mock_client_instance
            
            with patch('scripts.seed_scam_db.get_scam_database_tool') as mock_tool:
                mock_tool_instance = Mock()
                # Return False to simulate duplicate
                mock_tool_instance.add_report.return_value = False
                mock_tool.return_value = mock_tool_instance
                
                seeder = ScamDatabaseSeeder()
                await seeder.seed_from_phishtank(limit=1)
                
                assert seeder.stats['phishtank_added'] == 0
                assert seeder.stats['phishtank_duplicates'] == 1
    
    def test_ftc_csv_seeding(self, tmp_path):
        """Test FTC CSV data seeding."""
        from scripts.seed_scam_db import ScamDatabaseSeeder
        
        # Create test CSV file
        csv_content = """phone_number,complaint_type,date,description
+18005551234,IRS Scam,2025-10-01,Claimed to be IRS demanding payment
+18005555678,Tech Support,2025-10-02,Fake Microsoft tech support
"""
        csv_file = tmp_path / "test_ftc.csv"
        csv_file.write_text(csv_content)
        
        with patch('scripts.seed_scam_db.get_scam_database_tool') as mock_tool:
            mock_tool_instance = Mock()
            mock_tool_instance.add_report.return_value = True
            mock_tool.return_value = mock_tool_instance
            
            seeder = ScamDatabaseSeeder()
            seeder.seed_from_ftc_csv(str(csv_file))
            
            # Verify stats
            assert seeder.stats['ftc_added'] == 2
            assert seeder.stats['ftc_duplicates'] == 0
            
            # Verify calls
            assert mock_tool_instance.add_report.call_count == 2
            
            # Check first call
            first_call = mock_tool_instance.add_report.call_args_list[0]
            assert first_call[1]['entity_type'] == 'phone'
            assert first_call[1]['entity_value'] == '+18005551234'
            assert 'FTC Consumer Sentinel' in first_call[1]['evidence']['source']
    
    def test_manual_data_seeding(self):
        """Test manual curated data seeding."""
        from scripts.seed_scam_db import ScamDatabaseSeeder
        
        with patch('scripts.seed_scam_db.get_scam_database_tool') as mock_tool:
            mock_tool_instance = Mock()
            mock_tool_instance.add_report.return_value = True
            mock_tool.return_value = mock_tool_instance
            
            seeder = ScamDatabaseSeeder()
            seeder.seed_manual_data()
            
            # Verify some manual data was added
            assert seeder.stats['manual_added'] > 0
            
            # Verify add_report was called
            assert mock_tool_instance.add_report.call_count > 0


class TestPhishTankUpdater:
    """Test PhishTank daily update script."""
    
    @pytest.mark.asyncio
    async def test_fetch_recent_entries(self):
        """Test fetching recent PhishTank entries."""
        from scripts.update_phishtank import PhishTankUpdater
        
        # Mock data with recent and old entries
        now = datetime.now(timezone.utc)
        recent_time = (now - timedelta(hours=12)).isoformat()
        old_time = (now - timedelta(hours=72)).isoformat()
        
        mock_data = [
            {
                'phish_id': '1',
                'url': 'http://recent-scam.com',
                'submission_time': recent_time,
                'verified': 'yes'
            },
            {
                'phish_id': '2',
                'url': 'http://old-scam.com',
                'submission_time': old_time,
                'verified': 'yes'
            }
        ]
        
        with patch('httpx.AsyncClient') as mock_client:
            mock_response = Mock()
            mock_response.json.return_value = mock_data
            mock_response.raise_for_status = Mock()
            
            mock_client_instance = AsyncMock()
            mock_client_instance.__aenter__.return_value = mock_client_instance
            mock_client_instance.__aexit__.return_value = None
            mock_client_instance.get.return_value = mock_response
            mock_client.return_value = mock_client_instance
            
            updater = PhishTankUpdater()
            recent_entries = await updater.fetch_recent_entries(hours=48)
            
            # Should only get the recent entry
            assert len(recent_entries) == 1
            assert recent_entries[0]['phish_id'] == '1'
            assert updater.stats['total_fetched'] == 2
            assert updater.stats['recent_entries'] == 1
    
    @pytest.mark.asyncio
    async def test_update_database(self):
        """Test database update with recent entries."""
        from scripts.update_phishtank import PhishTankUpdater
        
        mock_entries = [
            {
                'phish_id': '123',
                'url': 'http://new-scam.com',
                'submission_time': '2025-10-18T10:00:00+00:00',
                'verified': 'yes'
            }
        ]
        
        with patch('scripts.update_phishtank.get_scam_database_tool') as mock_tool:
            mock_tool_instance = Mock()
            mock_tool_instance.add_report.return_value = True
            mock_tool.return_value = mock_tool_instance
            
            updater = PhishTankUpdater()
            await updater.update_database(mock_entries)
            
            assert updater.stats['added'] == 1
            assert updater.stats['skipped'] == 0
            
            # Verify evidence includes update timestamp
            call_args = mock_tool_instance.add_report.call_args
            evidence = call_args[1]['evidence']
            assert 'update_date' in evidence


class TestScamArchiver:
    """Test scam archival script."""
    
    def test_find_archival_candidates(self):
        """Test finding old reports for archival."""
        from scripts.archive_old_scams import ScamArchiver
        
        # Mock Supabase client
        with patch('scripts.archive_old_scams.get_supabase_client') as mock_client:
            # Create mock reports
            old_date = (datetime.now(timezone.utc) - timedelta(days=400)).isoformat()
            
            mock_reports = [
                {
                    'id': 1,
                    'entity_type': 'phone',
                    'entity_value': '+18005551234',
                    'last_reported': old_date,
                    'verified': False,
                    'risk_score': 50.0
                },
                {
                    'id': 2,
                    'entity_type': 'url',
                    'entity_value': 'old-scam.com',
                    'last_reported': old_date,
                    'verified': True,
                    'risk_score': 95.0  # High risk, should be kept
                },
                {
                    'id': 3,
                    'entity_type': 'email',
                    'entity_value': 'scam@example.com',
                    'last_reported': old_date,
                    'verified': False,
                    'risk_score': 60.0
                }
            ]
            
            mock_response = Mock()
            mock_response.data = mock_reports
            
            mock_table = Mock()
            mock_table.select.return_value.lt.return_value.execute.return_value = mock_response
            
            mock_client_instance = Mock()
            mock_client_instance.table.return_value = mock_table
            mock_client.return_value = mock_client_instance
            
            archiver = ScamArchiver()
            candidates = archiver.find_archival_candidates(days=365)
            
            # Should return 2 candidates (not the verified high-risk one)
            assert len(candidates) == 2
            assert candidates[0]['id'] == 1
            assert candidates[1]['id'] == 3
    
    def test_archive_reports(self):
        """Test archiving reports to archive table."""
        from scripts.archive_old_scams import ScamArchiver
        
        with patch('scripts.archive_old_scams.get_supabase_client') as mock_client:
            mock_reports = [
                {
                    'id': 1,
                    'entity_type': 'phone',
                    'entity_value': '+18005551234',
                    'last_reported': '2024-01-01T00:00:00+00:00'
                }
            ]
            
            mock_table = Mock()
            mock_table.insert.return_value.execute.return_value = Mock()
            mock_table.delete.return_value.in_.return_value.execute.return_value = Mock()
            
            mock_client_instance = Mock()
            mock_client_instance.table.return_value = mock_table
            mock_client.return_value = mock_client_instance
            
            archiver = ScamArchiver()
            archiver.archive_reports(mock_reports, batch_size=50)
            
            assert archiver.stats['archived'] == 1
            assert archiver.stats['failed'] == 0
            
            # Verify insert was called
            assert mock_table.insert.called
            
            # Verify delete was called
            assert mock_table.delete.called


class TestAdminEndpoints:
    """Test admin API endpoints."""
    
    @pytest.mark.asyncio
    async def test_create_scam_report(self):
        """Test POST /admin/scam-reports endpoint."""
        from app.main import app
        from fastapi.testclient import TestClient
        
        client = TestClient(app)
        
        payload = {
            "entity_type": "phone",
            "entity_value": "+18005551234",
            "evidence": {
                "source": "user_report",
                "date": "2025-10-18"
            },
            "notes": "Test scam report"
        }
        
        with patch('app.main.get_scam_database_tool') as mock_tool:
            mock_tool_instance = Mock()
            mock_tool_instance.add_report.return_value = True
            mock_tool.return_value = mock_tool_instance
            
            response = client.post("/admin/scam-reports", json=payload)
            
            assert response.status_code == 201
            data = response.json()
            assert data['message'] == "Scam report created successfully"
    
    @pytest.mark.asyncio
    async def test_list_scam_reports(self):
        """Test GET /admin/scam-reports endpoint."""
        from app.main import app
        from fastapi.testclient import TestClient
        
        client = TestClient(app)
        
        with patch('app.db.client.get_supabase_client') as mock_client:
            mock_reports = [
                {
                    'id': 1,
                    'entity_type': 'phone',
                    'entity_value': '+18005551234',
                    'risk_score': 85.0
                }
            ]
            
            mock_response = Mock()
            mock_response.data = mock_reports
            
            mock_table = Mock()
            mock_query = Mock()
            mock_query.order.return_value.limit.return_value.offset.return_value.execute.return_value = mock_response
            mock_table.select.return_value = mock_query
            
            mock_client_instance = Mock()
            mock_client_instance.table.return_value = mock_table
            mock_client.return_value = mock_client_instance
            
            response = client.get("/admin/scam-reports?limit=10&offset=0")
            
            assert response.status_code == 200
            data = response.json()
            assert data['count'] == 1
            assert len(data['reports']) == 1
    
    @pytest.mark.asyncio
    async def test_update_scam_report(self):
        """Test PATCH /admin/scam-reports/{id} endpoint."""
        from app.main import app
        from fastapi.testclient import TestClient
        
        client = TestClient(app)
        
        payload = {
            "verified": True,
            "risk_score": 95.0,
            "notes": "Manually verified as high-risk scam"
        }
        
        with patch('app.db.client.get_supabase_client') as mock_client:
            mock_updated_report = {
                'id': 1,
                'entity_type': 'phone',
                'entity_value': '+18005551234',
                'verified': True,
                'risk_score': 95.0
            }
            
            mock_response = Mock()
            mock_response.data = [mock_updated_report]
            
            mock_table = Mock()
            mock_table.update.return_value.eq.return_value.execute.return_value = mock_response
            
            mock_client_instance = Mock()
            mock_client_instance.table.return_value = mock_table
            mock_client.return_value = mock_client_instance
            
            response = client.patch("/admin/scam-reports/1", json=payload)
            
            assert response.status_code == 200
            data = response.json()
            assert data['message'] == "Scam report updated successfully"
            assert data['report']['verified'] == True
    
    @pytest.mark.asyncio
    async def test_delete_scam_report(self):
        """Test DELETE /admin/scam-reports/{id} endpoint."""
        from app.main import app
        from fastapi.testclient import TestClient
        
        client = TestClient(app)
        
        with patch('app.db.client.get_supabase_client') as mock_client:
            mock_response = Mock()
            mock_response.data = [{'id': 1}]
            
            mock_table = Mock()
            mock_table.delete.return_value.eq.return_value.execute.return_value = mock_response
            
            mock_client_instance = Mock()
            mock_client_instance.table.return_value = mock_table
            mock_client.return_value = mock_client_instance
            
            response = client.delete("/admin/scam-reports/1")
            
            assert response.status_code == 200
            data = response.json()
            assert data['message'] == "Scam report deleted successfully"
    
    @pytest.mark.asyncio
    async def test_get_analytics(self):
        """Test GET /admin/scam-analytics endpoint."""
        from app.main import app
        from fastapi.testclient import TestClient
        
        client = TestClient(app)
        
        with patch('app.db.client.get_supabase_client') as mock_client:
            mock_reports = [
                {
                    'id': 1,
                    'entity_type': 'phone',
                    'entity_value': '+18005551234',
                    'risk_score': 85.0,
                    'report_count': 10,
                    'verified': True,
                    'created_at': '2025-10-18T10:00:00+00:00'
                },
                {
                    'id': 2,
                    'entity_type': 'url',
                    'entity_value': 'scam.com',
                    'risk_score': 95.0,
                    'report_count': 50,
                    'verified': True,
                    'created_at': '2025-10-17T10:00:00+00:00'
                },
                {
                    'id': 3,
                    'entity_type': 'phone',
                    'entity_value': '+18005555678',
                    'risk_score': 30.0,
                    'report_count': 2,
                    'verified': False,
                    'created_at': '2025-10-16T10:00:00+00:00'
                }
            ]
            
            mock_response = Mock()
            mock_response.data = mock_reports
            
            mock_table = Mock()
            
            # Mock for all_reports query
            mock_table.select.return_value.execute.return_value = mock_response
            
            # Mock for top_scams query
            mock_top_response = Mock()
            mock_top_response.data = [mock_reports[1], mock_reports[0]]
            mock_table.select.return_value.order.return_value.limit.return_value.execute.return_value = mock_top_response
            
            # Mock for recent query  
            mock_recent_response = Mock()
            mock_recent_response.data = mock_reports
            
            mock_client_instance = Mock()
            mock_client_instance.table.return_value = mock_table
            mock_client.return_value = mock_client_instance
            
            response = client.get("/admin/scam-analytics")
            
            assert response.status_code == 200
            data = response.json()
            
            assert data['total_reports'] == 3
            assert 'phone' in data['by_type']
            assert 'url' in data['by_type']
            assert data['by_type']['phone'] == 2
            assert data['by_type']['url'] == 1
            
            # Check risk level breakdown
            assert 'low' in data['by_risk_level']
            assert 'high' in data['by_risk_level']
            assert 'critical' in data['by_risk_level']


if __name__ == "__main__":
    pytest.main([__file__, "-v"])


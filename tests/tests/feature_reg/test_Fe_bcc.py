
import pytest

@pytest.mark.bulk
@pytest.mark.magnetism
@pytest.mark.hdf
def DEACTIVATED_test_Fe_bcc_FlipcdnXLDA(execute_fleur, grep_number, grep_exists):
    """FeBCCFlipX: Flipcdn and noco in MT test
    Simple test of Fleur with two steps:
    1.Generate a rotated starting density and run 1 iteration
    2.Calculate magnetization and check it's value. 
    """
    test_file_folder = './inputfiles/Fe_bcc_FlipcdnXLDA/'
 
    # Stage 1
    files = ['inp.xml', 'kpts.xml', 'sym.xml', 'JUDFT_WARN_ONLY']
    res_files = execute_fleur(test_file_folder, only_copy=files)
    should_files = ['out']
    res_file_names = list(res_files.keys())
    for file1 in should_files:
        assert file1 in res_file_names
    
    assert grep_exists(res_files['out'], "flip")

    # Stage 2
    res_files = execute_fleur(test_file_folder, only_copy=[['inp2.xml', 'inp.xml', 'JUDFT_WARN_ONLY']])
    mx = grep_number(res_files['out'], "mx=", "mx=")
    assert abs(mx - 2.116) <= 0.001


@pytest.mark.bulk
@pytest.mark.magnetism
@pytest.mark.hdf
def DEACTIVATED_test_Fe_bcc_FlipcdnYGGA(execute_fleur, grep_number, grep_exists):
    """FeBCCFlipY: Flipcdn and noco in MT test
    Simple test of Fleur with two steps:
    1.Generate a rotated starting density and run 1 iteration
    2.Calculate magnetization and check it's value. 
    """
    test_file_folder = './inputfiles/Fe_bcc_FlipcdnYGGA/'

    # Stage 1
    files = ['inp.xml', 'kpts.xml', 'sym.xml', 'JUDFT_WARN_ONLY']
    res_files = execute_fleur(test_file_folder, only_copy=files)
    should_files = ['out']
    res_file_names = list(res_files.keys())
    for file1 in should_files:
        assert file1 in res_file_names

    assert grep_exists(res_files['out'], "flip")

    # Stage 2
    res_files = execute_fleur(test_file_folder, only_copy=[['inp2.xml', 'inp.xml'], 'JUDFT_WARN_ONLY'])
    my = grep_number(res_files['out'], "my=", "my=")
    assert abs(my + 2.180) <= 0.001

@pytest.mark.bulk
@pytest.mark.magnetism
@pytest.mark.hdf
def test_Fe_bcc_SF_LDA(default_fleur_test):
    """FeBCCSFLDA: Sourcefree magnetism and magnetization scaling

    Simple test of Fleur with one step:
    1.Generate a starting density in z-direction, calculate the potential and make it sourcefree. 
    Check for the correct transformed magnetic field. And the correct resulting magnetization.
    """
    assert default_fleur_test("Fe_bcc_SF_LDA")
    
@pytest.mark.bulk
@pytest.mark.magnetism
@pytest.mark.soc
def test_Fe_bcc_orbital_polarization_correction(default_fleur_test):
    """
    Test of the orbital polarization correction

    Simple Fleur test with one step:
    1.Run 12 iterations with a orbital polarization correction added on the 3d states and
      check for the correct orbital moment
    """
    assert default_fleur_test("Fe_bcc_OPC")
    